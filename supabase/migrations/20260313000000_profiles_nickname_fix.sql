-- 1. profiles 테이블 존재 확인 및 기본 구조 보장
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT,
  couple_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. RLS 활성화
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. RLS 정책 설정 (기존 정책 삭제 후 재설정)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone" 
ON public.profiles FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- (선택 사항) 커플인 경우 서로의 프로필을 업데이트할 수 있게 허용할지 여부
-- 사용자가 요청한 "파트너 이름 설정" 기능이 작동하려면 이 정책이 필요할 수 있습니다.
DROP POLICY IF EXISTS "Users can update their partner's profile" ON public.profiles;
CREATE POLICY "Users can update their partner's profile"
ON public.profiles FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.profiles my_profile
    WHERE my_profile.id = auth.uid()
    AND my_profile.couple_id = public.profiles.couple_id
  )
);

-- 4. 신규 유저 생성 시 프로필 자동 생성 트리거 함수 수정
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nickname', '사용자')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 트리거 재설정 (삭제 후 생성)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
