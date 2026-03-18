const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ODSAY_BASE = 'https://api.odsay.com/v1/api'
const ODSAY_KEY = Deno.env.get('ODSAY_API_KEY') ?? ''

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const endpoint = url.searchParams.get('endpoint')

    if (!endpoint) {
      return new Response(
        JSON.stringify({ error: { msg: 'endpoint parameter required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // 허용된 엔드포인트만 프록시 (보안)
    const allowed = [
      'trainTerminals',
      'expressBusTerminals',
      'intercityBusTerminals',
      'trainServiceTime',
      'searchInterBusSchedule',
    ]
    if (!allowed.includes(endpoint)) {
      return new Response(
        JSON.stringify({ error: { msg: 'endpoint not allowed' } }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // 프록시 파라미터 조합 (endpoint 제거, apiKey 서버에서 추가)
    const params = new URLSearchParams()
    for (const [key, value] of url.searchParams.entries()) {
      if (key !== 'endpoint') params.set(key, value)
    }
    params.set('apiKey', ODSAY_KEY)

    const odsayUrl = `${ODSAY_BASE}/${endpoint}?${params.toString()}`
    console.log(`[odsay-proxy] → ${endpoint}?${params.toString().replace(ODSAY_KEY, '***')}`)

    const response = await fetch(odsayUrl)
    const text = await response.text()

    console.log(`[odsay-proxy] ← status=${response.status} body=${text.substring(0, 200)}`)

    return new Response(text, {
      status: response.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('[odsay-proxy] error:', e)
    return new Response(
      JSON.stringify({ error: { msg: String(e) } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
