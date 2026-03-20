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

    const systemMessage = `당신은 근무표(교대 근무 스케줄표) 이미지 분석 전문가입니다.
표 구조를 정확히 파악하고 특정 인물의 근무 일정을 추출합니다.
반드시 JSON만 출력하고 다른 텍스트는 절대 출력하지 마세요.`

    const userPrompt = `## 작업
이 이미지에서 "${targetName}"의 근무 일정을 추출하세요.

## STEP 1 — 표 구조 파악
먼저 표의 방향을 결정하세요:
- [가로형] 첫 번째 열에 이름들이 나열되고, 첫 번째 행에 날짜(1, 2, 3...)가 있는 형식
- [세로형] 첫 번째 행에 이름들이 나열되고, 첫 번째 열에 날짜가 있는 형식

## STEP 2 — 연도·월 파악
이미지에서 연도와 월을 찾으세요 (예: "2026년 3월", "3월", "March 2026").
찾지 못하면 기본값 ${targetYear}년 ${targetMonth}월 사용.

## STEP 3 — 이름 찾기
"${targetName}" 텍스트를 포함하는 행(또는 열)을 찾으세요.
- 부분 일치 허용 (예: "홍길동" 입력 시 "홍길동A", "홍길동(정)" 도 허용)
- 대소문자 무시

## STEP 4 — 날짜-근무 매핑
날짜 헤더와 "${targetName}" 행(또는 열)을 교차하여 각 날짜의 근무 값을 읽으세요.
- 셀 값 있는 것은 모두 기록 (빈 칸만 제외)
- X, x, ×, ✕, O, △, ○ 포함한 모든 기호·텍스트를 있는 그대로 기록
- 흐릿하거나 불확실한 경우 가장 가까운 값을 추정하여 기록

## STEP 5 — 색상 매핑
| 근무 유형 | 키워드 | color_hex |
|----------|--------|-----------|
| 주간 | 주, D, Day, AM, 오전, 낮, 早 | #4CAF50 |
| 야간 | 야, N, Night, PM(23시~), 밤, 夜 | #3F51B5 |
| 저녁 | E, Evening, PM, 오후, 석 | #FF9800 |
| 휴무/오프 | 휴, X, x, O, Off, 오프, 비번, 공휴, 휴가, 연차, △ | #9E9E9E |
| 당직 | 당, On-call, 비상 | #9C27B0 |
| 기타/불명 | 그 외 모든 값 | #607D8B |

## 출력
아래 JSON만 출력 (다른 텍스트 없이):
{"year":숫자,"month":숫자,"schedules":[{"start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD","work_type":"원본텍스트그대로","color_hex":"#RRGGBB"}]}

규칙:
- "${targetName}" 없으면 → {"year":${targetYear},"month":${targetMonth},"schedules":[]}
- 하루 근무: start_date == end_date
- work_type은 이미지에 있는 텍스트/기호를 그대로 사용 (변환하지 말 것)
- 날짜 형식: YYYY-MM-DD (예: 2026-03-15)`

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
