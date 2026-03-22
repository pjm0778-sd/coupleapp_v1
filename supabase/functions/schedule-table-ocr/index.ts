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

    const systemMessage = `당신은 기울어진 이미지에서도 정확하게 근무표를 분석하는 전문가입니다.
손으로 촬영한 이미지의 기울기로 인해 행이 드리프트되는 오류를 방지하고,
특정 인물의 근무 일정만 정확히 추출합니다.
반드시 JSON만 출력하고 다른 텍스트는 절대 출력하지 마세요.`

    const userPrompt = `이 이미지에서 "${targetName}"의 근무 일정을 추출하세요.

## STEP 1 — 표 방향 파악
- [가로형] 첫 번째 열 = 이름 목록, 첫 번째 행 = 날짜(1, 2, 3...)
- [세로형] 첫 번째 행 = 이름 목록, 첫 번째 열 = 날짜

## STEP 2 — 연도·월 확인
이미지에서 연도와 월을 찾으세요. 없으면 기본값: ${targetYear}년 ${targetMonth}월

## STEP 2.5 — 날짜 헤더 선(先) 열거
날짜 헤더(가로형: 첫 번째 행 / 세로형: 첫 번째 열)의 날짜 번호를 1일부터 끝까지 전부 확인하세요.
각 날짜 번호가 이미지의 어느 위치(몇 번째 칸)에 있는지 확정한 뒤, 이후 단계에서 이 위치를 기준으로 TARGET 행과 교차하세요.
날짜 위치를 먼저 고정해두면 기울기로 인한 열(column) 드리프트를 크게 줄일 수 있습니다.

## STEP 3 — 샌드위치 앵커 설정
이름 열(또는 이름 행)의 모든 이름을 순서대로 파악한 뒤, "${targetName}"의 위아래 이름을 확인하세요:
- ABOVE: "${targetName}" 바로 위의 이름
- TARGET: "${targetName}" (부분 일치 허용 — 예: "홍길동A", "홍길동(정)")
- BELOW: "${targetName}" 바로 아래의 이름

이 세 이름이 전체 추출 과정의 앵커입니다. ABOVE는 위쪽 경계, BELOW는 아래쪽 경계입니다.
TARGET이 첫 번째 행이면 ABOVE 없음, 마지막 행이면 BELOW 없음으로 처리하세요.

## STEP 4 — 날짜-근무 매핑

[5일 주기 재보정]
1일, 6일, 11일, 16일, 21일, 26일을 읽기 직전, 반드시 이름 열로 시선을 되돌리세요.
현재 행 = TARGET인지, 바로 위 행 = ABOVE인지, 바로 아래 행 = BELOW인지 삼중 확인 후 계속하세요.

[샌드위치 검증]
각 날짜 칸을 읽을 때, 같은 날짜의 바로 위(ABOVE 행) 칸과 바로 아래(BELOW 행) 칸을 함께 보세요.
위아래가 ABOVE·BELOW의 값으로 확인되면 → 현재 칸이 정확한 TARGET 값임.
읽으려는 칸이 ABOVE 또는 BELOW 행에 더 가깝다는 느낌이 들면 → 드리프트 발생,
즉시 이름 열로 돌아가 TARGET 행을 재탐색한 뒤 해당 날짜부터 다시 읽으세요.

[격자선 추적]
표가 기울어져 있어도 각 행은 상단·하단 경계선을 가집니다. 이 경계선도 함께 기울어져 있습니다.
날짜를 오른쪽으로 이동할수록 TARGET 행 경계선의 기울기 방향을 따라가며,
경계선 안쪽에 위치한 셀의 내용만 읽으세요. 경계선을 넘은 내용은 읽지 마세요.

읽을 값: 빈 칸 제외, 나머지 모든 텍스트·기호를 있는 그대로 기록.
불확실한 경우 ABOVE·BELOW 행과 비교해 가장 그럴듯한 값을 추정하세요.

## STEP 5 — 색상 매핑
| 근무 유형 | 키워드 | color_hex |
|----------|--------|-----------|
| 주간 | 주, D, Day, AM, 오전 | #4CAF50 |
| 야간 | 야, N, Night, 밤 | #3F51B5 |
| 저녁 | E, Evening, PM, 오후 | #FF9800 |
| 휴무 | 휴, X, O, Off, 오프, 비번, 연차, △ | #9E9E9E |
| 당직 | 당, On-call | #9C27B0 |
| 기타 | 그 외 모든 값 | #607D8B |

## 출력
JSON만 출력 (코드블록 없이):
{"year":숫자,"month":숫자,"schedules":[{"start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD","work_type":"원본텍스트","color_hex":"#RRGGBB"}]}

- "${targetName}" 없으면 → {"year":${targetYear},"month":${targetMonth},"schedules":[]}
- 하루 근무: start_date == end_date
- work_type: 이미지의 텍스트·기호 그대로 사용
- 날짜 형식: YYYY-MM-DD`

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
