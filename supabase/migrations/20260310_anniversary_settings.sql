-- AnniversarySettings 테이블 생성 - 커플 기념일 관리

CREATE TABLE IF NOT EXISTS anniversary_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  anniversary_type VARCHAR(50) NOT NULL,
  custom_name VARCHAR(100),
  custom_month INT,
  custom_day INT,
  is_enabled BOOLEAN DEFAULT TRUE,
  reminder_days INT[] DEFAULT ARRAY[7, 1],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_anniversary_settings_couple_id ON anniversary_settings(couple_id);
CREATE INDEX idx_anniversary_settings_enabled ON anniversary_settings(is_enabled);

-- 기본 기념일 데이터 (새 커플 생성 시 자동 삽입 트리거에서 참조)
-- 화이트데이, 발렌타인데이, 크리스마스, 100일, 1년 등
