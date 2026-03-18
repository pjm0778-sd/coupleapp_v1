-- owner_type 컬럼 추가 (캘린더 재설계 - 일정 소유자 구분)
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS owner_type TEXT DEFAULT 'me'
  CHECK (owner_type IN ('me', 'partner', 'couple'));

-- 기존 isDate=true 데이터를 couple로 마이그레이션
UPDATE schedules SET owner_type = 'couple' WHERE is_date = TRUE;

-- 인덱스 (정렬 성능)
CREATE INDEX IF NOT EXISTS idx_schedules_owner_type ON schedules(owner_type);
