const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const KAKAO_REST_KEY = Deno.env.get('KAKAO_REST_API_KEY') ?? ''

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const mode = url.searchParams.get('mode') ?? 'keyword'

    // ── category 검색 (midpoint-date 장소 추천) ──
    if (mode === 'category') {
      const category = url.searchParams.get('category')
      const x = url.searchParams.get('x')
      const y = url.searchParams.get('y')
      const radius = url.searchParams.get('radius') ?? '5000'

      if (!category || !x || !y) {
        return new Response(
          JSON.stringify({ error: 'category, x, y parameters required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }

      const kakaoUrl = `https://dapi.kakao.com/v2/local/search/category.json`
        + `?category_group_code=${category}&x=${x}&y=${y}&radius=${radius}&size=10&sort=distance`

      const res = await fetch(kakaoUrl, {
        headers: { Authorization: `KakaoAK ${KAKAO_REST_KEY}` },
      })

      if (!res.ok) {
        return new Response(
          JSON.stringify({ error: `Kakao API error: ${res.status}` }),
          { status: res.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }

      const data = await res.json()
      const places = (data.documents ?? []).map((d: Record<string, string>) => ({
        name: d.place_name,
        address: d.road_address_name || d.address_name,
        lat: parseFloat(d.y),
        lng: parseFloat(d.x),
        category: d.category_name,
        kakaoUrl: d.place_url,
      }))

      return new Response(
        JSON.stringify({ places }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ── keyword 검색 (기존 동작) ──
    const query = url.searchParams.get('query')

    if (!query) {
      return new Response(
        JSON.stringify({ error: 'query parameter required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const kakaoUrl = `https://dapi.kakao.com/v2/local/search/keyword.json?query=${encodeURIComponent(query)}&size=10`
    const res = await fetch(kakaoUrl, {
      headers: { Authorization: `KakaoAK ${KAKAO_REST_KEY}` },
    })

    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: `Kakao API error: ${res.status}` }),
        { status: res.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const data = await res.json()
    const places = (data.documents ?? []).map((d: Record<string, string>) => ({
      name: d.place_name,
      address: d.road_address_name || d.address_name,
      lat: parseFloat(d.y),
      lng: parseFloat(d.x),
      category: d.category_name,
    }))

    return new Response(
      JSON.stringify({ places }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
