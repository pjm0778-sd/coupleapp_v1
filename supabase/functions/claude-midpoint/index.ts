const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CLAUDE_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
const CLAUDE_MODEL = 'claude-haiku-4-5-20251001'

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

    const prompt = `당신은 한국 커플 여행 전문가입니다.
두 사람이 공평하게 이동할 수 있는 중간지점 도시를 추천해주세요.

- A 출발지: ${myOrigin} / 교통수단: ${modeLabel(myMode, myCarType)}
- B 출발지: ${partnerOrigin} / 교통수단: ${modeLabel(partnerMode, partnerCarType)}
- 테마: ${themeLabel(theme)}

조건:
1. 두 사람의 예상 이동시간이 최대한 비슷할 것 (30분 이내 차이 권장)
2. 테마에 맞는 도시 특성 반영
3. 한국 내 실제 도시만 추천 (읍·면 단위 제외, 시·구 단위)
4. 교통수단 특성 반영: 대중교통이면 역/터미널 접근 가능한 도시 우선

아래 JSON 형식으로만 응답하세요. 다른 텍스트 없이 JSON만:
{
  "cities": [
    {
      "name": "도시명",
      "reason": "추천 이유 (2문장 이내, 이동시간 균형 + 테마 특성 포함)",
      "estimatedMinutesA": 90,
      "estimatedMinutesB": 85
    }
  ]
}

도시는 2~3곳 추천하세요.`

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
