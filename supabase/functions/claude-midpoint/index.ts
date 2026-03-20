const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CLAUDE_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
const CLAUDE_MODEL   = 'claude-haiku-4-5-20251001'  // 설명만 생성 → Haiku로 충분

// POST { cities: ["서울", "대전", "대구"], theme: "date" | "travel" | "simple" }
// 도시 선정·시간 추정은 더 이상 담당하지 않음 → 설명 텍스트만 생성

function themeLabel(theme: string): string {
  if (theme === 'date')   return '데이트 (카페·맛집·분위기 중심)'
  if (theme === 'travel') return '여행 (관광지·문화·자연 중심)'
  return '만남의 장소'
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
    const body = await req.json()
    const cities: string[] = body.cities ?? []
    const theme: string    = body.theme ?? 'simple'

    if (cities.length === 0) {
      return new Response(
        JSON.stringify({ descriptions: {} }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const prompt = `다음 도시들의 ${themeLabel(theme)} 관점 특징을 간단히 설명해주세요.

도시 목록: ${cities.join(', ')}

각 도시마다 1~2문장으로 테마에 맞는 매력을 설명하세요.
이동시간이나 거리 정보는 절대 포함하지 마세요.

JSON만 응답하세요:
{
  "descriptions": {
    "도시명": "설명 1~2문장",
    ...
  }
}`

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 512,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!claudeRes.ok) {
      console.error('[claude-midpoint] Claude API error:', claudeRes.status)
      // 실패해도 빈 설명으로 진행 (필수 아님)
      return new Response(
        JSON.stringify({ descriptions: {} }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const data    = await claudeRes.json()
    const content = data.content?.[0]?.text ?? ''
    const match   = content.match(/\{[\s\S]*\}/)

    if (!match) {
      return new Response(
        JSON.stringify({ descriptions: {} }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = JSON.parse(match[0])
    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('[claude-midpoint] error:', e)
    return new Response(
      JSON.stringify({ descriptions: {} }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
