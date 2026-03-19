const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CLAUDE_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
const CLAUDE_MODEL = 'claude-sonnet-4-6'

interface MidpointRequest {
  myOrigin: string
  partnerOrigin: string
  myMode: 'publicTransit' | 'car'
  myCarType?: 'normal' | 'electric'
  partnerMode: 'publicTransit' | 'car'
  partnerCarType?: 'normal' | 'electric'
  theme: 'date' | 'travel' | 'simple'
}

function modeLabel(mode: string, carType?: string): string {
  if (mode === 'car') return carType === 'electric' ? '전기차' : '자차'
  return '대중교통'
}

function themeLabel(theme: string): string {
  if (theme === 'date') return '데이트 (카페·맛집 중심)'
  if (theme === 'travel') return '여행 (관광지·숙박 중심)'
  return '단순 중간지점 (거리 최소화)'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'POST method required' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  try {
    const body: MidpointRequest = await req.json()
    const { myOrigin, partnerOrigin, myMode, myCarType, partnerMode, partnerCarType, theme } = body

    if (!myOrigin || !partnerOrigin || !myMode || !partnerMode || !theme) {
      return new Response(
        JSON.stringify({ error: 'myOrigin, partnerOrigin, myMode, partnerMode, theme are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const prompt = `당신은 한국 지리와 교통에 정통한 전문가입니다.
두 사람이 각자 출발지에서 비슷한 시간에 도착할 수 있는 중간지점 도시를 추천해주세요.

[입력]
- A 출발지: ${myOrigin} / 교통수단: ${modeLabel(myMode, myCarType)}
- B 출발지: ${partnerOrigin} / 교통수단: ${modeLabel(partnerMode, partnerCarType)}
- 테마: ${themeLabel(theme)}

[이동시간 추정 기준]
- 자차: 시내 30km/h, 고속도로 100km/h 기준
- 대중교통 단거리(~50km): 지하철·버스 40~70분
- 대중교통 중거리(50~200km): 고속버스 1~2시간 / KTX·SRT 30~60분
- 대중교통 장거리(200km+): KTX·SRT 1~2시간 / 고속버스 2~4시간

[⚠️ KTX 미경유 도시 주의 - 반드시 환승 시간 포함]
다음 도시들은 KTX가 없어 고속버스 또는 서울 경유 환승이 필수입니다:
- 속초: 서울 강남/동서울 고속버스 2시간 30분~3시간. 타 지방 이동 시 서울 경유 필수 → 총 4~6시간
- 강릉: 서울 청량리 KTX 2시간. 타 지방 이동 시 서울 경유 필수 → 총 3~5시간
- 동해·삼척·태백: 버스 위주, 서울 경유 시 3~5시간
- 여수·순천: KTX 있음 (서울~여수 3시간), 속초→여수 직접 이동 불가, 서울 경유 5~6시간

[한국 주요 도시 간 거리 참고]
- 서울~대전: 약 140km (KTX 50분, 자차 1시간 30분)
- 서울~대구: 약 240km (KTX 1시간 40분, 자차 2시간 30분)
- 서울~부산: 약 400km (KTX 2시간 30분, 자차 4시간)
- 서울~광주광역시: 약 300km (KTX 1시간 30분, 자차 3시간)
- 서울~전주: 약 240km (KTX 1시간 10분, 자차 2시간 30분)
- 서울~속초: 약 200km (고속버스 2시간 30분, 자차 2시간 30분)
- 서울~강릉: 약 230km (KTX 2시간, 자차 2시간 30분)
- 속초~광주광역시: 약 490km 직선, 대중교통으로 서울 경유 시 5~7시간
- 속초~대전: 약 300km, 대중교통으로 서울 경유 시 4~5시간
- 대전~광주광역시: 약 180km (KTX 40분, 자차 1시간 50분)
- 수원·오산·평택: 서울 남쪽 40~80km 수도권 권역

[추천 원칙 - 반드시 준수]
1. 두 사람의 이동시간 차이가 30분 이내여야 합니다
2. 한쪽 출발지에서 30분 이내 거리인 도시는 절대 추천하지 마세요 (불공평)
3. A와 B의 거리가 멀수록 중간지점도 두 도시 사이 어딘가여야 합니다
4. 수도권(서울/경기)과 지방 광역시 사이라면 충청권(대전·천안·청주 등)이 적절합니다
5. 대중교통이면 KTX·SRT 정차역 또는 고속버스 터미널이 있는 도시 우선
6. 직선거리 300km 이상이면 estimatedMinutes는 자차 최소 180분, 대중교통 최소 150분 이상이어야 합니다
7. KTX 미경유 도시(속초·강릉 등)에서 출발하면 환승 시간을 반드시 포함하여 실제보다 낮게 추정하지 마세요

[검증 단계 - 추천 전 반드시 확인]
- 추천 도시에서 A까지 예상 이동시간을 계산하세요 (환승 포함)
- 추천 도시에서 B까지 예상 이동시간을 계산하세요 (환승 포함)
- 두 시간 차이가 30분 초과하면 다른 도시로 교체하세요
- estimatedMinutes가 직선거리 대비 비현실적으로 짧으면 다시 계산하세요

JSON만 응답하세요 (다른 텍스트 없음):
{
  "cities": [
    {
      "name": "도시명",
      "reason": "[테마에 맞는 이 도시의 특징과 매력 1~2문장. 소요시간은 절대 포함하지 마세요]",
      "estimatedMinutesA": 90,
      "estimatedMinutesB": 85
    }
  ]
}

도시 2~3곳 추천하세요.`

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!claudeRes.ok) {
      const err = await claudeRes.text()
      console.error('[claude-midpoint] Claude API error:', err)
      return new Response(
        JSON.stringify({ error: `Claude API error: ${claudeRes.status}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const claudeData = await claudeRes.json()
    const content = claudeData.content?.[0]?.text ?? ''

    // JSON 파싱 (Claude가 마크다운 코드블록으로 감쌀 수 있으므로 추출)
    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      console.error('[claude-midpoint] JSON not found in response:', content)
      return new Response(
        JSON.stringify({ error: 'Invalid Claude response format' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = JSON.parse(jsonMatch[0])
    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('[claude-midpoint] error:', e)
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
