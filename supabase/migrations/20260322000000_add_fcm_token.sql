-- profiles 테이블에 FCM 토큰 컬럼 추가
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;
