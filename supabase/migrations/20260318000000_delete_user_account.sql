-- ============================================================
-- 1. 유저 계정 전체 삭제 함수 (클라이언트 RPC 호출용)
--    - 커플 데이터, 일정, 색상매핑, 프로필, auth.users 순서로 삭제
-- ============================================================
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID;
  v_couple_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 커플 연결 여부 확인
  SELECT couple_id INTO v_couple_id
    FROM profiles WHERE id = v_user_id;

  IF v_couple_id IS NOT NULL THEN
    -- 커플 일정 댓글 삭제
    DELETE FROM schedule_comments
     WHERE schedule_id IN (SELECT id FROM schedules WHERE couple_id = v_couple_id);

    -- 커플 일정 삭제
    DELETE FROM schedules WHERE couple_id = v_couple_id;

    -- 색상 매핑 삭제 (두 사용자 모두)
    DELETE FROM color_mappings
     WHERE user_id IN (SELECT id FROM profiles WHERE couple_id = v_couple_id)
        OR user_id = v_user_id;

    -- 파트너 프로필의 couple_id NULL 처리
    UPDATE profiles
       SET couple_id = NULL
     WHERE couple_id = v_couple_id
       AND id != v_user_id;

    -- 커플 레코드 삭제
    DELETE FROM couples WHERE id = v_couple_id;

  ELSE
    -- 미연결 초대코드 삭제 (user1로 생성만 한 couples 행)
    DELETE FROM couples WHERE user1_id = v_user_id AND user2_id IS NULL;
    -- 개인 색상 매핑 삭제
    DELETE FROM color_mappings WHERE user_id = v_user_id;
  END IF;

  -- 프로필 삭제
  DELETE FROM profiles WHERE id = v_user_id;

  -- auth.users 삭제 (SECURITY DEFINER 권한으로 가능)
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;


-- ============================================================
-- 2. Supabase 대시보드에서 auth.users 직접 삭제 시 cascade 처리
--    profiles 테이블 DELETE 트리거 → 관련 데이터 전체 정리
-- ============================================================
CREATE OR REPLACE FUNCTION handle_profile_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_couple_id UUID;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- 커플 일정 댓글 삭제
    DELETE FROM schedule_comments
     WHERE schedule_id IN (SELECT id FROM schedules WHERE couple_id = v_couple_id);

    -- 커플 일정 삭제
    DELETE FROM schedules WHERE couple_id = v_couple_id;

    -- 색상 매핑 삭제 (커플 멤버 전체 + 탈퇴 유저)
    DELETE FROM color_mappings
     WHERE user_id IN (SELECT id FROM profiles WHERE couple_id = v_couple_id)
        OR user_id = OLD.id;

    -- 파트너 프로필 couple_id NULL 처리
    UPDATE profiles
       SET couple_id = NULL
     WHERE couple_id = v_couple_id
       AND id != OLD.id;

    -- 커플 레코드 삭제
    DELETE FROM couples WHERE id = v_couple_id;

  ELSE
    -- 미연결 초대코드 삭제
    DELETE FROM couples WHERE user1_id = OLD.id AND user2_id IS NULL;
    -- 색상 매핑 삭제
    DELETE FROM color_mappings WHERE user_id = OLD.id;
  END IF;

  RETURN OLD;
END;
$$;

-- 트리거 등록 (profiles 행 삭제 직전 실행)
DROP TRIGGER IF EXISTS on_profile_delete ON profiles;
CREATE TRIGGER on_profile_delete
  BEFORE DELETE ON profiles
  FOR EACH ROW EXECUTE FUNCTION handle_profile_delete();
