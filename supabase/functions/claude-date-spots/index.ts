const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const NAVER_CLIENT_ID     = Deno.env.get('NAVER_SEARCH_CLIENT_ID') ?? ''
const NAVER_CLIENT_SECRET = Deno.env.get('NAVER_SEARCH_CLIENT_SECRET') ?? ''

function stripHtml(s: string): string {
  return s.replace(/<[^>]*>/g, '').trim()
}

function inferCategory(naverCategory: string): string {
  if (naverCategory.includes('카페') || naverCategory.includes('커피')) return '카페'
  if (naverCategory.includes('음식') || naverCategory.includes('식당') || naverCategory.includes('한식')
    || naverCategory.includes('일식') || naverCategory.includes('중식') || naverCategory.includes('양식')) return '음식점'
  if (naverCategory.includes('관광') || naverCategory.includes('명소') || naverCategory.includes('공원')
    || naverCategory.includes('해수욕') || naverCategory.includes('문화')) return '명소'
  if (naverCategory.includes('쇼핑') || naverCategory.includes('시장') || naverCategory.includes('백화점')) return '쇼핑'
  if (naverCategory.includes('체험') || naverCategory.includes('레저') || naverCategory.includes('스포츠')) return '체험'
  return '명소'
}

async function searchPlace(
  query: string,
  defaultCategory: string,
  exclude: Set<string> = new Set(),
): Promise<{ name: string; category: string; description: string; tip: string } | null> {
  try {
    const url = `https://openapi.naver.com/v1/search/local.json?query=${encodeURIComponent(query)}&display=5&sort=comment`
    const res = await fetch(url, {
      headers: {
        'X-Naver-Client-Id': NAVER_CLIENT_ID,
        'X-Naver-Client-Secret': NAVER_CLIENT_SECRET,
      },
    })
    if (!res.ok) return null
    const data = await res.json()
    const items: unknown[] = data.items ?? []

    // exclude에 없는 첫 번째 결과 선택
    for (const item of items as Record<string, string>[]) {
      const name = stripHtml(item.title)
      if (exclude.has(name)) continue

      const category = inferCategory(item.category ?? '') || defaultCategory
      const address  = item.roadAddress || item.address || ''

      return {
        name,
        category,
        description: `${item.category ? item.category + ' · ' : ''}리뷰 많은 인기 장소`,
        tip: address ? `📍 ${address}` : '네이버 지도에서 위치 확인',
      }
    }
    return null
  } catch (e) {
    console.error('[claude-date-spots] naver search error:', e)
    return null
  }
}

const PREVIEW_QUERIES = (city: string) => [
  { query: `${city} 카페`,     defaultCategory: '카페' },
  { query: `${city} 관광명소`, defaultCategory: '명소' },
  { query: `${city} 맛집`,     defaultCategory: '음식점' },
]

const MORE_QUERIES = (city: string) => [
  { query: `${city} 브런치 카페`,  defaultCategory: '카페' },
  { query: `${city} 야경 뷰포인트`, defaultCategory: '명소' },
  { query: `${city} 전통시장`,     defaultCategory: '쇼핑' },
  { query: `${city} 체험 액티비티`, defaultCategory: '체험' },
  { query: `${city} 이자카야 술집`, defaultCategory: '음식점' },
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url  = new URL(req.url)
    const city = url.searchParams.get('city')
    const mode = url.searchParams.get('mode') ?? 'preview'

    if (!city) {
      return new Response(
        JSON.stringify({ error: 'city parameter required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const excludeParam = url.searchParams.get('exclude') ?? ''
    const excludeSet = new Set(
      excludeParam ? excludeParam.split(',').map(decodeURIComponent) : []
    )

    const queries = mode === 'preview' ? PREVIEW_QUERIES(city) : MORE_QUERIES(city)
    const results = await Promise.all(queries.map(q => searchPlace(q.query, q.defaultCategory, excludeSet)))
    const spots   = results.filter(Boolean)

    return new Response(
      JSON.stringify({ spots }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('[claude-date-spots] error:', e)
    return new Response(
      JSON.stringify({ spots: [] }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
