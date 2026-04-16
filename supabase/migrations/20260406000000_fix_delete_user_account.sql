-- 계정 삭제 RPC를 단순화하고, Storage 소유 객체가 있을 때 원인을 명확히 반환
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_storage_object_count BIGINT := 0;
  v_storage_bucket_count BIGINT := 0;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  BEGIN
    SELECT COUNT(*)
      INTO v_storage_object_count
      FROM storage.objects
     WHERE owner = v_user_id
        OR owner_id = v_user_id::text;
  EXCEPTION
    WHEN undefined_column THEN
      SELECT COUNT(*)
        INTO v_storage_object_count
        FROM storage.objects
       WHERE owner = v_user_id;
  END;

  SELECT COUNT(*)
    INTO v_storage_bucket_count
    FROM storage.buckets
   WHERE owner = v_user_id;

  IF v_storage_object_count > 0 OR v_storage_bucket_count > 0 THEN
    RAISE EXCEPTION
      'Account deletion blocked: remove owned storage files first. objects=%, buckets=%',
      v_storage_object_count,
      v_storage_bucket_count
      USING HINT = 'Supabase Dashboard > Storage에서 이 계정이 소유한 파일을 먼저 삭제한 뒤 다시 시도하세요.';
  END IF;

  -- profiles_id_fkey가 CASCADE가 아니더라도 앱 내 탈퇴는 동작하도록
  -- 프로필을 먼저 삭제하고, profiles 삭제 트리거가 관련 공개 스키마 데이터를 정리한다.
  DELETE FROM profiles WHERE id = v_user_id;

  BEGIN
    DELETE FROM auth.users WHERE id = v_user_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'User not found';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION
        'Failed to delete auth user: %',
        SQLERRM
        USING HINT = 'profiles_id_fkey 같은 auth/public 스키마 참조 제약이나 Storage 파일 소유권을 확인하세요.';
  END;
END;
$$;

REVOKE ALL ON FUNCTION delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;