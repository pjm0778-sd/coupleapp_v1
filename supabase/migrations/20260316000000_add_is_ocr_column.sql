-- OCR 자동등록 일정 구분 컬럼 추가
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS is_ocr boolean DEFAULT false;
