import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// FCM v1 API — 서비스 계정 JSON으로 액세스 토큰 생성 후 전송
const FCM_PROJECT_ID = 'coupleduty-1158a'
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`

// 서비스 계정 JSON에서 JWT assertion으로 OAuth2 토큰 획득
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const signingInput = `${encode(header)}.${encode(payload)}`

  // PEM 키 파싱
  const pemKey = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')

  const keyData = Uint8Array.from(atob(pemKey), (c) => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const encoder = new TextEncoder()
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(signingInput),
  )

  const sigBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

  const jwt = `${signingInput}.${sigBase64}`

  // OAuth2 토큰 교환
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) {
    throw new Error(`OAuth2 토큰 실패: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token as string
}

interface ServiceAccount {
  client_email: string
  private_key: string
}

interface NotificationPayload {
  token: string
  title: string
  body: string
  type: string
}

async function sendFcmNotification(payload: NotificationPayload): Promise<void> {
  const serviceAccountStr = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!serviceAccountStr) throw new Error('FCM_SERVICE_ACCOUNT 환경변수 없음')

  const serviceAccount: ServiceAccount = JSON.parse(serviceAccountStr)
  const accessToken = await getAccessToken(serviceAccount)

  const res = await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          type: payload.type,
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: { sound: 'default', badge: 1 },
          },
        },
      },
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`FCM 전송 실패: ${err}`)
  }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  try {
    const body = await req.json()
    const { type, record, old_record } = body

    // Supabase Database Webhook 페이로드
    const newRecord = record as Record<string, unknown> | null
    const oldRecord = old_record as Record<string, unknown> | null

    if (!newRecord && !oldRecord) {
      return new Response('No record', { status: 400 })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 변경된 일정의 userId 확인 (DELETE면 old_record에서)
    const activeRecord = (newRecord ?? oldRecord) as Record<string, unknown>
    const scheduleUserId = activeRecord['user_id'] as string
    const coupleId = activeRecord['couple_id'] as string

    if (!scheduleUserId || !coupleId) {
      return new Response('Missing user_id or couple_id', { status: 400 })
    }

    // 파트너 userId 조회
    const { data: couple } = await supabase
      .from('couples')
      .select('user1_id, user2_id')
      .eq('id', coupleId)
      .maybeSingle()

    if (!couple) return new Response('Couple not found', { status: 404 })

    const partnerId =
      couple.user1_id === scheduleUserId ? couple.user2_id : couple.user1_id

    // 파트너 FCM 토큰 조회
    const { data: partnerProfile } = await supabase
      .from('profiles')
      .select('fcm_token, nickname')
      .eq('id', partnerId)
      .maybeSingle()

    const fcmToken = partnerProfile?.fcm_token as string | null
    if (!fcmToken) {
      return new Response('Partner has no FCM token', { status: 200 })
    }

    // 이벤트 타입별 알림 내용
    const date = (activeRecord['start_date'] ?? activeRecord['date']) as string | null
    const dateStr = date ? new Date(date).toLocaleDateString('ko-KR', { month: 'long', day: 'numeric' }) : ''

    let title = ''
    let notifBody = ''
    let notifType = ''

    switch (type) {
      case 'INSERT':
        title = '✨ 파트너가 일정을 추가했어요'
        notifBody = dateStr ? `${dateStr} 일정이 추가되었어요` : '새 일정이 추가되었어요'
        notifType = 'schedule_added'
        break
      case 'UPDATE':
        title = '📝 파트너가 일정을 수정했어요'
        notifBody = dateStr ? `${dateStr} 일정이 수정되었어요` : '일정이 수정되었어요'
        notifType = 'schedule_updated'
        break
      case 'DELETE':
        title = '🗑️ 파트너가 일정을 삭제했어요'
        notifBody = dateStr ? `${dateStr} 일정이 삭제되었어요` : '일정이 삭제되었어요'
        notifType = 'schedule_deleted'
        break
      default:
        return new Response('Unknown event type', { status: 400 })
    }

    await sendFcmNotification({ token: fcmToken, title, body: notifBody, type: notifType })

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('send-notification error:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
