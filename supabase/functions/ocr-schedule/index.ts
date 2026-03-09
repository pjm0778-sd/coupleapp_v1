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

사용자가 등록한 색상-근무형태 매핑 (참고용 색상 코드):
${colorMappingText}

분석 지침:
1. 달력의 각 날짜 칸에 표시된 색상(배경색, 텍스트 색상, 도형 색상 등)을 확인하세요.
2. 위 매핑의 색상 코드는 정확한 값이 아닌 참고용입니다. 이미지의 색상과 시각적으로 가장 유사한 매핑을 선택하세요.
   예) 매핑에 "#FF5252(빨강)"이 있고 이미지에서 주황빛 빨강이 보이면 → 빨강 매핑으로 처리
3. 색상이 전혀 없는 날짜(흰색 또는 회색 빈 칸)는 제외하세요.
4. 색상이 있지만 매핑에 가장 가까운 것을 찾을 수 없는 경우, 가장 시각적으로 유사한 매핑을 사용하세요.
5. color_hex에는 이미지에서 실제로 보이는 색상의 근사 hex 값을 넣어주세요.

반드시 아래 JSON 배열 형식으로만 응답하세요 (다른 설명 없이):
[{"date":"${targetYear}-${String(targetMonth).padStart(2, '0')}-DD","work_type":"근무형태","color_hex":"#XXXXXX"}]

DD는 실제 날짜 숫자(01~31)로 채우세요.`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: {
                  url: `data:${imageMediaType ?? 'image/jpeg'};base64,${imageBase64}`,
                  detail: 'high',
                },
              },
              {
                type: 'text',
                text: prompt,
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error(`OpenAI API error: ${errText}`)
    }

    const data = await response.json()
    const content = data.choices?.[0]?.message?.content ?? '[]'

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
