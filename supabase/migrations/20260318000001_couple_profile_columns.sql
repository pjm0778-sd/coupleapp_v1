-- couple-profile-setup 기능에 필요한 profiles 컬럼 추가
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS distance_type      VARCHAR(20)  DEFAULT 'same_city',
  ADD COLUMN IF NOT EXISTS my_city            VARCHAR(100),
  ADD COLUMN IF NOT EXISTS my_station         VARCHAR(100),
  ADD COLUMN IF NOT EXISTS partner_city       VARCHAR(100),
  ADD COLUMN IF NOT EXISTS partner_station    VARCHAR(100),
  ADD COLUMN IF NOT EXISTS work_pattern       VARCHAR(20)  DEFAULT 'office',
  ADD COLUMN IF NOT EXISTS shift_times        JSONB        DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notify_minutes_before INT       DEFAULT 30,
  ADD COLUMN IF NOT EXISTS has_car            BOOLEAN      DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN    DEFAULT false;

-- 이 마이그레이션 이전 가입자(기존 유저)는 온보딩 완료 처리
-- → 신규 INSERT는 DEFAULT false를 받아 온보딩 진입
UPDATE profiles
   SET onboarding_completed = true
 WHERE onboarding_completed = false;
