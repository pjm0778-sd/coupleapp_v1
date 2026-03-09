import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, imageMediaType, colorMappings, targetYear, targetMonth } =
      await req.json()

    const colorMappingText = (colorMappings as { color_hex: string; work_type: string }[])
      .map((m) => `${m.color_hex} → ${m.work_type}`)
      .join('\n')

    const prompt = `이 이미지는 ${targetYear}년 ${targetMonth}월 근무 스케줄 달력입니다.

사용자 색상-근무형태 매핑:
${colorMappingText}

분석 지침:
1. 달력의 각 날짜 칸의 배경색 또는 표시 색상을 확인하세요
2. 위 매핑표와 가장 유사한 색상을 찾아 근무형태를 결정하세요
3. 색상이 없거나 매핑에 해당하지 않는 날짜는 제외하세요

반드시 아래 JSON 배열 형식으로만 응답하세요 (다른 설명 없이):
[{"date":"${targetYear}-${String(targetMonth).padLeft(2, '0')}-01","work_type":"근무형태","color_hex":"#XXXXXX"}]`

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: imageMediaType ?? 'image/jpeg',
                  data: imageBase64,
                },
              },
              { type: 'text', text: prompt },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error(`Claude API error: ${errText}`)
    }

    const data = await response.json()
    const content = data.content?.[0]?.text ?? '[]'

    // JSON 배열 추출
    const match = content.match(/\[[\s\S]*\]/)
    const schedules = match ? JSON.parse(match[0]) : []

    return new Response(JSON.stringify({ schedules }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
