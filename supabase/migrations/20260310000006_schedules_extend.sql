-- Schedules 테이블 확장 - OCR 캘린더 기능
-- 기존 컬럼: id, user_id, couple_id, date, work_type, color_hex, note, is_date, emoji

ALTER TABLE schedules
ADD COLUMN IF NOT EXISTS title VARCHAR(200),
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME,
ADD COLUMN IF NOT EXISTS category VARCHAR(50)
  CHECK (category IN ('근무', '약속', '여행', '데이트', '기타')),
ADD COLUMN IF NOT EXISTS location VARCHAR(200),
ADD COLUMN IF NOT EXISTS reminder_minutes INT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS repeat_pattern JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_anniversary BOOLEAN DEFAULT FALSE;

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_schedules_category ON schedules(category);
CREATE INDEX IF NOT EXISTS idx_schedules_date_category ON schedules(date, category);
CREATE INDEX IF NOT EXISTS idx_schedules_couple_date ON schedules(couple_id, date);
