const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, imageMediaType, colorMappings, targetYear, targetMonth } =
      await req.json()

    const colorMappingText = (colorMappings as { color_hex: string; work_type: string }[])
      .map((m) => `${m.color_hex} → ${m.work_type}`)
      .join('\n')

    const prompt = `이 이미지는 ${targetYear}년 ${targetMonth}월 근무 스케줄 달력입니다.

사용자가 등록한 색상-근무형태 매핑 (참고용 색상 코드):
${colorMappingText}

[중요] 색상 판별 정확도를 위한 상세 지침:

1. 주요 색상 식별 우선순위:
   - 1순위: 날짜 칸의 전체 배경색 (가장 큰 영역을 차지하는 색)
   - 2순위: 날짜 칸 내부의 도형/마커 색상 (원, 사각형 등)
   - 3순위: 날짜 숫자 텍스트 색상 (마지막 우선순위)

2. 경계선/그리드 무시:
   - 달력 셀의 경계선, 구분선, 그리드 색상은 근무 색상으로 간주하지 마세요
   - 숫자 주변의 얇은 선, 박스 테두리는 무시하고 셀 내부 색상만 봐주세요

3. 색상 비교 방법:
   - RGB/HEX 색상 값을 수치로 비교하세요. 단순히 "비슷해 보인다"로 판단하지 마세요
   - 예: 매핑에 #2196F3(파랑)이 있고 이미지에서 #1565C0(진한 파랑)이면 → 가장 유사한 파랑 매핑
   - 밝기 차이는 허용하되, 색상 계열(RGB 비율)이 달라지면 다른 매핑으로 처리하세요

4. 인접 날짜와 패턴 비교:
   - 인접한 날짜들의 색상 패턴을 참고하여 특정 날짜의 색상을 확인하세요
   - 주변 날짜들과 전혀 다른 색상이 보이면 분석 오류 가능성이 높습니다

5. 불확실한 경우는 스킵:
   - 색상이 너무 희미하거나 텍스트만 있는 경우 → 추출하지 마세요
   - 배경이 흰색/회색이고 아무런 색상 마커가 없는 경우 → 추출하지 마세요
   - 어떤 매핑에도 속하지 않는 명확한 다른 색상이면 → 추출하지 마세요

6. 빈 날짜 제외:
   - 흰색 또는 회색 배경만 있는 날짜는 제외하세요
   - 숫자만 표시되고 색상이 없는 날짜는 제외하세요

[정확성 요청] 날짜 하나를 잘못된 색으로 분석하는 오류가 발생했습니다. 위 지침을 철저히 준수하여 정확도를 높여주세요.

반드시 아래 JSON 배열 형식으로만 응답하세요 (다른 설명 없이):
[{"date":"${targetYear}-${String(targetMonth).padStart(2, '0')}-DD","work_type":"근무형태","color_hex":"#XXXXXX"}]

DD는 실제 날짜 숫자(01~31)로 채우세요.`

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
