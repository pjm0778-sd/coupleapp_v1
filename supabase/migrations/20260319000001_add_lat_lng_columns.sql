-- schedules 테이블에 위치 좌표 컬럼 추가 (카카오 지도 연동)
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
