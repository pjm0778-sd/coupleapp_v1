-- 커플 연결 끊기 및 데이터 전체 삭제 함수
CREATE OR REPLACE FUNCTION disconnect_couple(p_couple_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user1_id UUID;
  v_user2_id UUID;
  v_caller_id UUID;
BEGIN
  v_caller_id := auth.uid();

  -- 호출자가 해당 커플의 멤버인지 확인
  SELECT user1_id, user2_id
    INTO v_user1_id, v_user2_id
    FROM couples
   WHERE id = p_couple_id
     AND (user1_id = v_caller_id OR user2_id = v_caller_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION '커플 정보를 찾을 수 없거나 권한이 없습니다.';
  END IF;

  -- 1. 일정 댓글 삭제
  DELETE FROM schedule_comments
  WHERE schedule_id IN (
    SELECT id FROM schedules WHERE couple_id = p_couple_id
  );

  -- 2. 일정 삭제
  DELETE FROM schedules WHERE couple_id = p_couple_id;

  -- 3. 색상 매핑 삭제 (양쪽 사용자)
  DELETE FROM color_mappings
  WHERE user_id IN (v_user1_id, v_user2_id);

  -- 4. 프로필의 couple_id 초기화
  UPDATE profiles SET couple_id = NULL
  WHERE id IN (v_user1_id, v_user2_id);

  -- 5. 커플 레코드 삭제
  DELETE FROM couples WHERE id = p_couple_id;
END;
$$;

-- 인증된 사용자만 호출 가능
REVOKE ALL ON FUNCTION disconnect_couple(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION disconnect_couple(UUID) TO authenticated;
