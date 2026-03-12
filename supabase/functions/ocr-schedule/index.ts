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

    const colorMappingText = (colorMappings as { color_hex: string; work_type: string; start_time?: string; end_time?: string }[])
      .map((m) => `${m.color_hex} → ${m.work_type} (${m.start_time || ''}~${m.end_time || ''})`)
      .join('\n')

    let prompt: string
    if (useMapping) {
      // 매핑을 참고하는 모드 - 비슷한 색 계열도 인정
      prompt = `이 이미지는 근무 스케줄 달력입니다. 
      
[분석 지침]
1. 연도 및 월 식별: 이미지 내에서 해당 달력이 어느 연도와 어느 월인지 가장 먼저 찾아내세요. 만약 이미지에서 명확한 연도/월을 찾을 수 없다면 기본값으로 ${targetYear}년 ${targetMonth}월을 사용하세요.
2. 색상 계열 기준 매칭: 사용자가 등록한 색상-근무형태 매핑 (${colorMappingText})을 참고하되, 정확히 일치하지 않아도 같은 색 계열(빨강, 파랑, 녹색 등)이면 매핑으로 인정하세요.
3. 주요 색상 식별: 날짜 칸의 배경색이나 칸 내부의 마커 색상을 우선으로 분석하세요.
4. 빈 날짜 스킵: 색상 마커나 배경색이 없는 날짜는 결과에서 제외하세요.
5. 시간 추가: 매핑에 시작/종료 시간이 있는 경우 결과에 포함하세요. (형식: "HH:mm")

반드시 아래 JSON 형식으로만 응답하세요 (다른 설명 없이):
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [{"date":"YYYY-MM-DD","work_type":"근무형태","color_hex":"#XXXXXX","start_time":"HH:mm","end_time":"HH:mm"}]
}`
    } else {
      // 매핑 무시 모드 - 사진의 색/글씨를 정확히 파악
      prompt = `이 이미지는 근무 스케줄 달력입니다.

[분석 지침]
1. 연도 및 월 식별: 이미지 내에서 해당 달력이 어느 연도와 어느 월인지 가장 먼저 찾아내세요. 만약 이미지에서 명확한 연도/월을 찾을 수 없다면 기본값으로 ${targetYear}년 ${targetMonth}월을 사용하세요.
2. 색상/텍스트 정확 파악: 각 날짜의 실제 배경색(HEX)과 표시된 텍스트(근무명)를 정확히 파악하여 일정을 만드세요.
3. 빈 날짜 스킵: 색상 마커나 배경색이 없는 날짜는 결과에서 제외하세요.

반드시 아래 JSON 형식으로만 응답하세요 (다른 설명 없이):
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [{"date":"YYYY-MM-DD","work_type":"근무형태","color_hex":"#XXXXXX"}]
}`
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
    const content = data.choices?.[0]?.message?.content ?? '{}'

    // JSON 추출 (객체 형태 {year, month, schedules})
    const match = content.match(/\{[\s\S]*\}/)
    const resultJson = match ? JSON.parse(match[0]) : { year: targetYear, month: targetMonth, schedules: [] }

    return new Response(JSON.stringify(resultJson), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
