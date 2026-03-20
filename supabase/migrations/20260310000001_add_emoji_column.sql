-- Add emoji column to schedules table
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS emoji VARCHAR(10);

-- Add default emoji to existing date schedules (optional)
UPDATE schedules SET emoji = '❤️' WHERE is_date = true AND emoji IS NULL;
