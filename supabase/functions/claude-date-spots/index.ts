const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CLAUDE_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
const CLAUDE_MODEL = 'claude-haiku-4-5-20251001'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url     = new URL(req.url)
    const city    = url.searchParams.get('city')
    const theme   = url.searchParams.get('theme') ?? 'date'
    const mode    = url.searchParams.get('mode') ?? 'preview'   // 'preview' | 'more'
    const exclude = url.searchParams.get('exclude') ?? ''        // comma-separated names

    if (!city) {
      return new Response(
        JSON.stringify({ error: 'city parameter required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    let prompt: string
    let maxTokens: number

    if (mode === 'preview') {
      prompt = `${city}의 대표 데이트 장소 3곳을 추천해주세요.
반드시 아래 3가지 카테고리에서 각 1곳씩 선택하세요:
1. 카페 (감성 있는 유명 카페)
2. 명소 (관광지, 공원, 문화공간 등)
3. 음식점 (유명 맛집)

실제로 유명하고 SNS·블로그에서 커플 데이트 코스로 자주 소개되는 곳만 추천하세요.

JSON만 응답 (다른 텍스트 없음):
{"spots":[{"name":"실제 장소명","category":"카페|명소|음식점","description":"유명한 이유 1문장","tip":"방문 팁 1문장"}]}`
      maxTokens = 512
    } else {
      const excludeList = exclude ? `이미 추천된 곳은 제외하세요: ${exclude}\n` : ''
      prompt = `${city}의 데이트 장소 5곳을 추가 추천해주세요.
${excludeList}
카페, 명소, 음식점, 체험, 쇼핑 등 다양한 카테고리로 추천하세요.
실제로 유명하고 SNS·블로그에서 자주 소개되는 곳만 추천하세요.

JSON만 응답 (다른 텍스트 없음):
{"spots":[{"name":"실제 장소명","category":"카페|음식점|명소|체험|쇼핑","description":"유명한 이유 1문장","tip":"방문 팁 1문장"}]}`
      maxTokens = 1024
    }

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: maxTokens,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!claudeRes.ok) {
      console.error('[claude-date-spots] Claude API error:', await claudeRes.text())
      return new Response(
        JSON.stringify({ spots: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const claudeData = await claudeRes.json()
    const content = claudeData.content?.[0]?.text ?? ''

    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      return new Response(
        JSON.stringify({ spots: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = JSON.parse(jsonMatch[0])
    return new Response(
      JSON.stringify(result),
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
