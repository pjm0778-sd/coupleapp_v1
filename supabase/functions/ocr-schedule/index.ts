const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, imageMediaType, targetYear, targetMonth } =
      await req.json()

    // ── 시스템 메시지: 역할 고정 ──
    const systemMessage = `당신은 달력 이미지에서 일정을 빠짐없이 정확하게 추출하는 전문가입니다.
반드시 분석 과정을 먼저 서술한 뒤 JSON을 출력하는 방식으로 응답하세요.
이미지는 삼성 캘린더, 아이폰 기본 캘린더, 구글 캘린더 등 다양한 앱의 캡처일 수 있습니다.`

    // ── 공통 지침 ──
    const instructions = `
【STEP 1 — 연도·월 파악】
달력 상단 제목을 읽어 연도와 월을 파악하세요.
제목이 없으면 날짜 숫자 배치와 요일로 유추하고, 그래도 모를 때만 기본값(${targetYear}년 ${targetMonth}월)을 사용하세요.

【STEP 2 — 격자 구조 파악】
요일 헤더(일/월/화/수/목/금/토 또는 Sun/Mon…)로 각 열의 요일을 확인하세요.
1일이 어느 열(요일)에서 시작하는지 확인하고, 이를 기준으로 전체 날짜 위치를 계산하세요.
날짜 번호는 반드시 요일 헤더와 열 위치를 대조해서 검증하세요.

【STEP 3 — 일정 전수 조사 (누락 금지)】
1행부터 마지막 행까지 모든 셀을 좌→우, 위→아래 순서로 스캔하세요.
아래 표시 중 하나라도 있으면 일정으로 기록하세요:
  - 색상 배경 블록 또는 가로 막대(bar)
  - 텍스트 레이블
  - 색상 점(dot) 또는 밑줄
여러 날에 걸친 bar는 bar가 시작하는 날짜 ~ 끝나는 날짜를 하나의 일정으로 기록하세요.
같은 셀에 일정이 여러 개면 모두 기록하세요.
이전 달·다음 달 날짜의 일정은 제외하세요.

【텍스트 읽기 원칙 — 최우선】
이미지에 글자가 보이면 반드시 그 글자를 work_type으로 사용하세요.
"야간", "주간", "연차", "휴무", "출장" 등 일정 위나 안에 적힌 텍스트를 정확히 읽으세요.
색상 기반 이름(예: "파란 일정")은 텍스트가 전혀 없을 때만 사용하세요.`

    const userPrompt = `${instructions}

【출력 형식】
먼저 아래 분석 섹션을 작성한 뒤, 결과 JSON을 출력하세요.

## 분석
- 연도/월: [파악한 값]
- 1일 요일: [무슨 요일]
- 발견한 일정 목록: [날짜: 텍스트 내용(텍스트 없으면 색상명) 형태로 행별 나열]

## 결과
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
- 하루짜리 일정은 start_date == end_date
- start_time·end_time은 이미지에 시간 정보가 있을 때만 포함, 없으면 해당 필드 생략
- color_hex는 #RRGGBB 형식
- work_type은 이미지에 보이는 텍스트를 최우선으로 사용. 텍스트가 전혀 없을 때만 색상 기반 이름(예: "파란 일정") 사용. null 금지`

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
    console.log('API Key exists:', apiKey.length > 0, '/ Key prefix:', apiKey.substring(0, 7))

    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY secret이 설정되지 않았습니다')
    }

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 4096,
        system: systemMessage,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: userPrompt,
              },
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

    console.log('Claude response status:', response.status)
    if (!response.ok) {
      const errText = await response.text()
      console.log('Claude error body:', errText)
      throw new Error(`Claude API error ${response.status}: ${errText}`)
    }

    const data = await response.json()
    const content = data.content?.[0]?.text ?? '{}'
    console.log('Claude raw response:', content)

    // JSON 추출 (코드블록 및 분석 섹션 제거 후 파싱)
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

    // start_date null 필터
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
