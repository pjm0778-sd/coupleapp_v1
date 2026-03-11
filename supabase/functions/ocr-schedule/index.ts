const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, imageMediaType, colorMappings, targetYear, targetMonth, useMapping = true } =
      await req.json()

    const colorMappingText = (colorMappings as { color_hex: string; work_type: string }[])
      .map((m) => `${m.color_hex} → ${m.work_type}`)
      .join('\n')

    let prompt: string
    if (useMapping) {
      // 매핑을 참고하는 모드 - 비슷한 색 계열도 인정
      prompt = `이 이미지는 ${targetYear}년 ${targetMonth}월 근무 스케줄 달력입니다.

사용자가 등록한 색상-근무형태 매핑 (색 계열 기준으로 비슷한 색도 인정합니다):
${colorMappingText}

[색상 계열 기준 매핑 지침]
같은 색 계열(빨강, 파랑, 녹색, 주황, 보라 등)은 정확히 일치하지 않아도 유사한 것으로 판단하세요.

색상 계열 예시:
- 빨강 계열: #FF0000, #E53935, #EF5350, #F44336, #E91E63, #FF4081
- 파랑 계열: #2196F3, #1976D2, #1565C0, #0D47A1, #3F51B5, #5C6BC0
- 녹색 계열: #4CAF50, #43A047, #388E3C, #66BB6A
- 주황 계열: #FF9800, #F57C00, #EF6C00, #FFB74D
- 노랑 계열: #FFEB3B, #FDD835, #FFC107, #FFD54F
- 보라 계열: #9C27B0, #8E24AA, #7B1FA2, #AB47BC
- 회색 계열: #9E9E9E, #757575, #BDBDBD, #E0E0E0

[분석 지침]

1. 색상 계열 기준 매칭:
   - 매핑 색상과 완전히 동일하지 않아도 같은 계열이면 매핑으로 인정하세요
   - 예: 매핑에 #2196F3(파랑)이 있고 이미지에서 #1565C0(진한 파랑)이면 → 매핑 사용
   - 예: 매핑에 #FF4081(분홍)이 있고 이미지에서 #E91E63(짙은 분홍)이면 → 매핑 사용

2. 주요 색상 식별:
   - 날짜 칸의 배경색이 가장 우선
   - 배경이 흰/회색이면 칸 내부의 마커/도형 색상
   - 경계선, 그리드, 테두리는 무시

3. 인접 패턴 참고:
   - 주변 날짜들의 색상 패턴을 보고 특정 날짜 색상을 판단
   - 주변과 전혀 다른 색은 분석 오류일 가능성

4. 빈 날짜 스킵:
   - 흰/회색 배경만 있거나 색상 마커가 없으면 제외

반드시 아래 JSON 배열 형식으로만 응답하세요 (다른 설명 없이):
[{"date":"${targetYear}-${String(targetMonth).padStart(2, '0')}-DD","work_type":"근무형태","color_hex":"#XXXXXX"}]

DD는 실제 날짜 숫자(01~31)로 채우세요.`
    } else {
      // 매핑 무시 모드 - 사진의 색/글씨를 정확히 파악
      prompt = `이 이미지는 ${targetYear}년 ${targetMonth}월 근무 스케줄 달력입니다.

[매핑 무시 모드 - 사진을 보고 센스 있게 분석하세요]
미리 설정된 색상 매핑은 무시하고, 사진 속의 실제 색과 텍스트를 정확히 파악하여 일정을 만들어주세요.

[분석 지침 - 유저 관점]

1. 색상/텍스트 정확 파악:
   - 각 날짜의 실제 배경색을 HEX로 추출
   - 같은 계열의 색이면 하나로 통합 (예: 연한 파랑과 진한 파랑이 섞여있으면 대표색 하나 선택)
   - 일정 이름은 달력에 표시된 텍스트 그대로 (근무, 야근, 휴무 등)

2. 색상 통합 규칙 (센스 있게):
   - 빨강/분홍 계열: 가장 진한 빨강/분홍 선택
   - 파랑 계열: 가장 진한 파랑 선택
   - 녹색 계열: 가장 진한 녹색 선택
   - 노랑/주황 계열: 가장 진한 주황/노랑 선택
   - 보라 계열: 가장 진한 보라 선택
   - 회색/흰색: 휴무/휴일로 간주

3. 일정 이름 센스 있게 판단:
   - 빨강/분홍 = 근무, 야근
   - 파랑 = 낮근, 근무
   - 녹색 = 근무, 주간근무
   - 노랑/주황 = 야근
   - 보라 = 특근, 교육
   - 회색/흰색 = 휴무, 연차
   - 텍스트가 있으면 그 텍스트 우선

4. 빈 날짜 스킵:
   - 색상 마커나 배경색이 없으면 제외

반드시 아래 JSON 배열 형식으로만 응답하세요 (다른 설명 없이):
[{"date":"${targetYear}-${String(targetMonth).padStart(2, '0')}-DD","work_type":"근무형태","color_hex":"#XXXXXX"}]

DD는 실제 날짜 숫자(01~31)로 채우세요.`
    }

    const apiKey = Deno.env.get('OPENAI_API_KEY') ?? ''
    console.log('API Key exists:', apiKey.length > 0, '/ Key prefix:', apiKey.substring(0, 7))

    if (!apiKey) {
      throw new Error('OPENAI_API_KEY secret이 설정되지 않았습니다')
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: {
                  url: `data:${imageMediaType ?? 'image/jpeg'};base64,${imageBase64}`,
                  detail: 'high',
                },
              },
              {
                type: 'text',
                text: prompt,
              },
            ],
          },
        ],
      }),
    })

    console.log('OpenAI response status:', response.status)
    if (!response.ok) {
      const errText = await response.text()
      console.log('OpenAI error body:', errText)
      throw new Error(`OpenAI API error ${response.status}: ${errText}`)
    }

    const data = await response.json()
    const content = data.choices?.[0]?.message?.content ?? '[]'

    // JSON 배열 추출
    const match = content.match(/\[[\s\S]*\]/)
    const schedules = match ? JSON.parse(match[0]) : []

    return new Response(JSON.stringify({ schedules }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
