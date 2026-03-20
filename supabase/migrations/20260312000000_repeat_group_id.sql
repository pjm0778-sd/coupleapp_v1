-- 반복 일정 그룹 ID 컬럼 추가
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS repeat_group_id TEXT;

-- 반복 그룹 ID 인덱스 (그룹 조회 성능)
CREATE INDEX IF NOT EXISTS idx_schedules_repeat_group_id
  ON schedules(repeat_group_id)
  WHERE repeat_group_id IS NOT NULL;

-- 시작일 컬럼 추가 (이미 없다면)
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS end_date DATE;
