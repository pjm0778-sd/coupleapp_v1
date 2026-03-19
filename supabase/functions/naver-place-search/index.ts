const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const NAVER_CLIENT_ID = Deno.env.get('NAVER_SEARCH_CLIENT_ID') ?? ''
const NAVER_CLIENT_SECRET = Deno.env.get('NAVER_SEARCH_CLIENT_SECRET') ?? ''

// 네이버 검색 결과의 <b> 등 HTML 태그 제거
function stripHtml(str: string): string {
  return str.replace(/<[^>]*>/g, '')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const query = url.searchParams.get('query')

    if (!query) {
      return new Response(
        JSON.stringify({ error: 'query parameter required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const naverUrl = `https://openapi.naver.com/v1/search/local.json`
      + `?query=${encodeURIComponent(query)}&display=5&sort=random`

    const res = await fetch(naverUrl, {
      headers: {
        'X-Naver-Client-Id': NAVER_CLIENT_ID,
        'X-Naver-Client-Secret': NAVER_CLIENT_SECRET,
      },
    })

    if (!res.ok) {
      const err = await res.text()
      console.error('[naver-place-search] API error:', res.status, err)
      return new Response(
        JSON.stringify({ error: `Naver API error: ${res.status}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const data = await res.json()
    const items: Record<string, string>[] = data.items ?? []

    const places = items.map((item) => ({
      name: stripHtml(item.title),
      address: item.address,           // 지번 주소
      roadAddress: item.roadAddress,   // 도로명 주소
    }))

    return new Response(
      JSON.stringify({ places }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('[naver-place-search] error:', e)
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
