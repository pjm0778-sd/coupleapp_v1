const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const NAVER_CLIENT_ID = Deno.env.get('NAVER_CLIENT_ID') ?? ''
const NAVER_CLIENT_SECRET = Deno.env.get('NAVER_CLIENT_SECRET') ?? ''
const NAVER_DIRECTIONS_URL = 'https://naveropenapi.apigw.ntruss.com/map-direction-15/v1/driving'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    // start, goal: "경도,위도" 형식 (Naver API 스펙)
    const start = url.searchParams.get('start') // "126.9784,37.5665"
    const goal = url.searchParams.get('goal')   // "127.1088,37.4040"

    if (!start || !goal) {
      return new Response(
        JSON.stringify({ error: 'start and goal parameters required (format: "lng,lat")' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const naverUrl = `${NAVER_DIRECTIONS_URL}?start=${start}&goal=${goal}&option=trafast`
    console.log(`[naver-directions] ${start} → ${goal}`)

    const res = await fetch(naverUrl, {
      headers: {
        'X-NCP-APIGW-API-KEY-ID': NAVER_CLIENT_ID,
        'X-NCP-APIGW-API-KEY': NAVER_CLIENT_SECRET,
      },
    })

    if (!res.ok) {
      const err = await res.text()
      console.error('[naver-directions] API error:', res.status, err)
      return new Response(
        JSON.stringify({ error: `Naver API error: ${res.status}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const data = await res.json()

    // Naver Directions 응답에서 필요한 값만 추출
    const route = data.route?.trafast?.[0]
    if (!route) {
      return new Response(
        JSON.stringify({ error: 'No route found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const summary = route.summary
    const distanceKm = Math.round(summary.distance / 10) / 100   // m → km (소수점 2자리)
    const durationMinutes = Math.round(summary.duration / 60000) // ms → 분
    const tollFare = summary.tollFare ?? 0

    return new Response(
      JSON.stringify({ distanceKm, durationMinutes, tollFare }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('[naver-directions] error:', e)
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
