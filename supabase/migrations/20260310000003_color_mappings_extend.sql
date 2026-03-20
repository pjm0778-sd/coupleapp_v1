-- ColorMappings 테이블 확장 - 일정 자동등록 기능

ALTER TABLE color_mappings
ADD COLUMN IF NOT EXISTS title VARCHAR(200) NOT NULL,
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME;

-- 기존 데이터에 기본 제목 추가 (기존 work_type를 title로 사용)
UPDATE color_mappings
SET title = COALESCE(
  (SELECT work_type FROM schedules WHERE color_hex = color_mappings.color_hex LIMIT 1),
  '일정'
)
WHERE title IS NULL;
