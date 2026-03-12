-- Couples 테이블 확장 - 연애 시작일 관리

ALTER TABLE couples
ADD COLUMN IF NOT EXISTS started_at DATE;

-- 기존 커플 데이터에 연애 시작일 설정 (created_at을 참조)
UPDATE couples
SET started_at = DATE(created_at)
WHERE started_at IS NULL;
