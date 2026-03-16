const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, imageMediaType, targetName, targetYear, targetMonth } =
      await req.json()

    if (!targetName) throw new Error('targetName은 필수입니다')

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
    if (!apiKey) throw new Error('ANTHROPIC_API_KEY secret이 설정되지 않았습니다')

    const systemMessage = `당신은 근무표 이미지에서 특정 인물의 근무 일정을 추출하는 전문가입니다.
JSON만 출력하세요. 설명이나 분석 텍스트는 일절 출력하지 마세요.`

    const userPrompt = `이 이미지는 근무표(업무 스케줄표)입니다.
"${targetName}"이라는 이름의 행(또는 열)을 찾아 날짜별 근무 일정을 추출하세요.

【추출 방법】
1. 이름이 적힌 열 또는 행에서 "${targetName}" 텍스트를 찾으세요 (부분 일치 허용)
2. 날짜 헤더(숫자 1~31 또는 "1일" 형태)에서 각 칸의 날짜를 파악하세요
3. "${targetName}" 행의 각 날짜 칸에서 근무 종류를 읽으세요
4. 값이 비어 있거나 "-" 인 경우는 제외하세요

【날짜 파악】
연도·월 기본값: ${targetYear}년 ${targetMonth}월
이미지 상단·하단에 연도/월 정보가 있으면 그것을 우선 사용하세요.

【출력 형식】
아래 JSON만 출력하세요 (다른 텍스트 없이):
{"year":숫자,"month":숫자,"schedules":[{"start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD","work_type":"근무종류","color_hex":"#RRGGBB"}]}

【근무 종류 색상 매핑】
- 주간 / D / Day / 낮 / 오전 → #4CAF50
- 야간 / N / Night / 밤 / 심야 → #3F51B5
- 저녁 / E / Evening / PM / 오후 → #FF9800
- 휴무 / 오프 / Off / O / 휴가 / 공휴일 / 비번 → #9E9E9E
- 당직 / 비상 → #9C27B0
- 기타 / 알 수 없음 → #607D8B

【주의 사항】
- "${targetName}"을 찾지 못하면 schedules를 빈 배열([])로 반환하세요
- 하루짜리 근무는 start_date == end_date
- 연박 근무(야간 등)는 당일 기준으로 start_date에 기록하세요`

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 2000,
        system: systemMessage,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: userPrompt },
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: imageMediaType ?? 'image/jpeg',
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error(`Claude API error ${response.status}: ${errText}`)
    }

    const data = await response.json()
    const content = data.content?.[0]?.text ?? '{}'

    const cleaned = content
      .replace(/```json\s*/gi, '')
      .replace(/```\s*/g, '')
      .trim()
    const match = cleaned.match(/\{[\s\S]*\}/)
    const resultJson = match
      ? JSON.parse(match[0])
      : { year: targetYear, month: targetMonth, schedules: [] }

    resultJson.year = resultJson.year ?? targetYear
    resultJson.month = resultJson.month ?? targetMonth

    if (resultJson.schedules) {
      resultJson.schedules = (
        resultJson.schedules as Record<string, unknown>[]
      ).filter((s) => s['start_date'] != null)
    }

    return new Response(JSON.stringify(resultJson), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
