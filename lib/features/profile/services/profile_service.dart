import '../../../core/supabase_client.dart';
import '../models/couple_profile.dart';

class ProfileService {
  /// 내 프로필 로드
  Future<CoupleProfile?> loadMyProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .select(
          'distance_type, my_city, my_station, partner_city, partner_station, '
          'work_pattern, shift_times, notify_minutes_before, has_car, onboarding_completed',
        )
        .eq('id', userId)
        .maybeSingle();
    return data != null ? CoupleProfile.fromMap(data) : null;
  }

  /// 프로필 저장 (온보딩 완료 포함)
  Future<void> saveProfile(CoupleProfile profile) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update(profile.toMap()).eq('id', userId);
  }

  /// 사귄 날짜 저장 (couples 테이블 — 기존 로직 유지)
  Future<void> saveCoupleStartDate(DateTime date) async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();
    final coupleId = profile?['couple_id'] as String?;
    if (coupleId == null) return;
    await supabase
        .from('couples')
        .update({'started_at': date.toIso8601String().split('T')[0]})
        .eq('id', coupleId);
  }

  /// 닉네임 저장 (profiles 테이블 — 기존 로직 유지)
  Future<void> saveNickname(String nickname) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from('profiles')
        .update({'nickname': nickname})
        .eq('id', userId);
  }

  /// 파트너 프로필 로드 [GAP-FIX]
  Future<CoupleProfile?> loadPartnerProfile(String partnerId) async {
    final data = await supabase
        .from('profiles')
        .select(
          'id, user_id, couple_id, nickname, '
          'distance_type, my_city, my_station, partner_city, partner_station, '
          'work_pattern, shift_times, notify_minutes_before, has_car, onboarding_completed',
        )
        .eq('id', partnerId)
        .maybeSingle();
    return data != null ? CoupleProfile.fromMap(data) : null;
  }

  /// 온보딩 완료 여부 확인
  Future<bool> isOnboardingCompleted() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', userId)
        .maybeSingle();
    return data?['onboarding_completed'] as bool? ?? false;
  }
}
