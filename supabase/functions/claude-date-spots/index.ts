const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CLAUDE_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
const CLAUDE_MODEL = 'claude-sonnet-4-6'

function themeLabel(theme: string): string {
  if (theme === 'date')   return '데이트 (카페·맛집·감성 스팟 중심)'
  if (theme === 'travel') return '여행 (관광지·체험·숙박 중심)'
  return '일반 (음식점·명소 중심)'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const city  = url.searchParams.get('city')
    const theme = url.searchParams.get('theme') ?? 'date'

    if (!city) {
      return new Response(
        JSON.stringify({ error: 'city parameter required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const prompt = `당신은 한국 여행 전문가이자 데이트 플래너입니다.
${city}에서 연인이 함께 방문하기 좋은 실제 유명한 장소를 추천해주세요.

테마: ${themeLabel(theme)}

[추천 기준]
- ${city}에서 실제로 유명하고 인터넷에서 많이 언급되는 곳만 추천
- SNS·블로그에서 커플 데이트 코스로 자주 소개되는 곳 우선
- 현재 운영 중인 곳 위주 (폐업 가능성 낮은 유명 장소)
- 도시를 대표하는 명물·명소·맛집 포함

JSON만 응답하세요 (다른 텍스트 없음):
{
  "spots": [
    {
      "name": "실제 장소명",
      "category": "카페|음식점|명소|체험|쇼핑",
      "description": "이 장소가 유명한 이유와 특징 (1~2문장, 구체적으로)",
      "tip": "방문 팁 (예약 필요 여부, 대표 메뉴, 혼잡 시간대, 추천 이유 등)"
    }
  ]
}

5~7곳 추천하세요.`

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 2048,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!claudeRes.ok) {
      const err = await claudeRes.text()
      console.error('[claude-date-spots] Claude API error:', err)
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
