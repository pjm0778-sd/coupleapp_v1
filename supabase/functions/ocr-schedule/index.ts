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
      // 매핑 참고 모드
      prompt = `당신은 달력 이미지에서 일정을 추출하는 전문가입니다.

이미지는 안드로이드, 아이폰, 구글 캘린더, 삼성 캘린더 등 어떤 달력 앱의 캡처일 수도 있습니다.

【1단계: 연도와 월 파악】
달력 상단 제목(예: "2025년 12월", "December 2025", "12월 2025")을 읽어 연도와 월을 파악하세요.
제목이 보이지 않으면 날짜 숫자 배치와 요일로 유추하세요.
어떤 방법으로도 알 수 없을 때만 연도=${targetYear}, 월=${targetMonth}를 사용하세요.
파악한 연도와 월로 모든 날짜(start_date, end_date)를 구성하세요.

【2단계: 일정 추출】
이미지에 보이는 모든 일정을 빠짐없이 추출하세요:
- 여러 날에 걸친 가로 막대(bar) 일정은 시작일~종료일을 하나의 일정으로 추출
- 같은 날짜에 일정이 여러 개면 전부 추출
- 파악한 연도/월 범위를 벗어나는 날짜(이전 달, 다음 달)는 제외
- 일정이 없는 날짜는 포함하지 않음

아래는 사용자가 등록한 색상-근무형태 매핑입니다:
${colorMappingText}

각 일정의 색상이 위 매핑 중 하나와 유사하면 해당 work_type과 start_time, end_time을 사용하세요.
유사한 매핑이 없으면 이미지에서 읽은 텍스트나 색상 그대로 사용하세요.

반드시 아래 JSON 형식으로만 응답하세요. 코드블록(\`\`\`) 없이 순수 JSON만 출력하세요:
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [
    {
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "work_type": "일정명",
      "color_hex": "#RRGGBB",
      "start_time": "HH:mm",
      "end_time": "HH:mm"
    }
  ]
}

규칙:
- 하루짜리 일정은 start_date와 end_date를 동일하게 입력
- start_time, end_time은 매핑에 시간 정보가 있거나 이미지에 표시된 경우에만 포함, 없으면 해당 필드 생략
- color_hex는 일정의 배경색 또는 마커 색상 (#RRGGBB 형식)
- work_type은 반드시 문자열로 입력. 텍스트가 없으면 색상 기반 이름(예: "파란 일정", "빨간 일정") 사용. null 절대 금지`
    } else {
      // 자유 인식 모드 - 매핑 없이 이미지에서 직접 추출
      prompt = `당신은 달력 이미지에서 일정을 추출하는 전문가입니다.

이미지는 안드로이드, 아이폰, 구글 캘린더, 삼성 캘린더 등 어떤 달력 앱의 캡처일 수도 있습니다.

【1단계: 연도와 월 파악】
달력 상단 제목(예: "2025년 12월", "December 2025", "12월 2025")을 읽어 연도와 월을 파악하세요.
제목이 보이지 않으면 날짜 숫자 배치와 요일로 유추하세요.
어떤 방법으로도 알 수 없을 때만 연도=${targetYear}, 월=${targetMonth}를 사용하세요.
파악한 연도와 월로 모든 날짜(start_date, end_date)를 구성하세요.

【2단계: 일정 추출】
이미지에 보이는 모든 일정을 빠짐없이 추출하세요:
- 여러 날에 걸친 가로 막대(bar) 일정은 시작일~종료일을 하나의 일정으로 추출
- 같은 날짜에 일정이 여러 개면 전부 추출
- 파악한 연도/월 범위를 벗어나는 날짜(이전 달, 다음 달)는 제외
- 일정이 없는 날짜는 포함하지 않음

반드시 아래 JSON 형식으로만 응답하세요. 코드블록(\`\`\`) 없이 순수 JSON만 출력하세요:
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [
    {
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "work_type": "일정명 또는 색상 기반 분류",
      "color_hex": "#RRGGBB",
      "start_time": "HH:mm",
      "end_time": "HH:mm"
    }
  ]
}

규칙:
- 하루짜리 일정은 start_date와 end_date를 동일하게 입력
- start_time, end_time은 이미지에 시간 정보가 있을 때만 포함, 없으면 해당 필드 생략
- color_hex는 일정의 배경색 또는 마커 색상 (#RRGGBB 형식)
- work_type은 반드시 문자열로 입력. 텍스트가 없으면 색상 기반 이름(예: "파란 일정", "빨간 일정") 사용. null 절대 금지`
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
    console.log('GPT-4o raw response:', content)

    // JSON 추출 (코드블록 제거 후 파싱)
    const cleaned = content
      .replace(/```json\s*/gi, '')
      .replace(/```\s*/g, '')
      .trim()
    const match = cleaned.match(/\{[\s\S]*\}/)
    const resultJson = match ? JSON.parse(match[0]) : { year: targetYear, month: targetMonth, schedules: [] }

    // year/month 보정
    const finalYear = resultJson.year ?? targetYear
    const finalMonth = resultJson.month ?? targetMonth
    resultJson.year = finalYear
    resultJson.month = finalMonth

    // start_date/end_date null 보정: 날짜가 null이면 제거, year/month가 있으면 로그
    if (resultJson.schedules) {
      console.log('schedules before fix:', JSON.stringify(resultJson.schedules.slice(0, 3)))
      resultJson.schedules = (resultJson.schedules as Record<string, unknown>[]).filter(
        (s) => s['start_date'] != null
      )
    }

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
