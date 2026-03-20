-- Expand category CHECK constraint to include all values used in the app
-- Previous: ('근무', '약속', '여행', '데이트', '기타')
-- Added: '출근', '외출', '휴무', '기념일'
ALTER TABLE schedules DROP CONSTRAINT IF EXISTS schedules_category_check;
ALTER TABLE schedules
  ADD CONSTRAINT schedules_category_check
  CHECK (category IN ('근무', '출근', '외출', '약속', '여행', '데이트', '기타', '휴무', '기념일'));
