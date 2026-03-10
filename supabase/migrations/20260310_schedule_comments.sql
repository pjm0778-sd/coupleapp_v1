-- ScheduleComments 테이블 생성 - 일정 댓글 기능

CREATE TABLE IF NOT EXISTS schedule_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_schedule_comments_schedule_id ON schedule_comments(schedule_id);
CREATE INDEX idx_schedule_comments_created_at ON schedule_comments(created_at DESC);
CREATE INDEX idx_schedule_comments_user_id ON schedule_comments(user_id);
