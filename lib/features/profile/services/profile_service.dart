import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../models/couple_profile.dart';

class ProfileService {
  /// 내 프로필 로드
  Future<CoupleProfile?> loadMyProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await supabase
        .from('profiles')
        .select(
          'couple_type, distance_type, my_city, my_station, partner_city, partner_station, '
          'work_pattern, shift_times, notify_minutes_before, has_car, onboarding_completed',
        )
        .eq('id', userId)
        .maybeSingle();
    return data != null ? CoupleProfile.fromMap(data) : null;
  }

  /// 프로필 저장 (온보딩 완료 포함)
  Future<void> saveProfile(CoupleProfile profile) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('profiles').update(profile.toMap()).eq('id', userId);
  }

  /// 사귄 날짜 저장 (couples 테이블 — 기존 로직 유지)
  Future<void> saveCoupleStartDate(DateTime date) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
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
          'couple_type, distance_type, my_city, my_station, partner_city, partner_station, '
          'work_pattern, shift_times, notify_minutes_before, has_car, onboarding_completed',
        )
        .eq('id', partnerId)
        .maybeSingle();
    return data != null ? CoupleProfile.fromMap(data) : null;
  }

  /// 온보딩 완료 여부 확인
  Future<bool> isOnboardingCompleted() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await supabase
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', userId)
        .maybeSingle();
    return data?['onboarding_completed'] as bool? ?? false;
  }

  /// 설정 화면용 기본 정보 로드 (nickname, couple_id)
  /// 프로필이 없으면 userMetadata 닉네임으로 생성 후 반환
  Future<({String? nickname, String? coupleId})> loadBasicProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return (nickname: null, coupleId: null);
    final data = await supabase
        .from('profiles')
        .select('nickname, couple_id')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      // 트리거가 작동하지 않은 경우 대비 — 프로필 생성
      final fallbackNickname =
          user.userMetadata?['nickname'] as String? ?? '사용자';
      await supabase.from('profiles').insert({
        'id': user.id,
        'nickname': fallbackNickname,
      });
      return (nickname: fallbackNickname, coupleId: null);
    }

    return (
      nickname: data['nickname'] as String?,
      coupleId: data['couple_id'] as String?,
    );
  }

  /// 파트너 닉네임 저장 (파트너 프로필 업데이트)
  Future<void> savePartnerNickname({
    required String coupleId,
    required String nickname,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final couple = await supabase
        .from('couples')
        .select('user1_id, user2_id')
        .eq('id', coupleId)
        .maybeSingle();
    if (couple == null) return;
    final partnerId = couple['user1_id'] == userId
        ? couple['user2_id']
        : couple['user1_id'];
    if (partnerId == null) return;
    await supabase
        .from('profiles')
        .update({'nickname': nickname})
        .eq('id', partnerId as String);
  }

  /// 파트너 닉네임 로드 (couples + profiles 조인)
  Future<String?> loadPartnerNickname(String coupleId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final couple = await supabase
        .from('couples')
        .select('user1_id, user2_id, started_at')
        .eq('id', coupleId)
        .maybeSingle();
    if (couple == null) return null;
    final partnerId = couple['user1_id'] == userId
        ? couple['user2_id'] as String?
        : couple['user1_id'] as String?;
    if (partnerId == null || partnerId.isEmpty) return null;
    final partner = await supabase
        .from('profiles')
        .select('nickname')
        .eq('id', partnerId)
        .maybeSingle();
    return partner?['nickname'] as String?;
  }

  /// 파트너 프로필 실시간 스트림 (Supabase Realtime)
  ///
  /// [partnerId]에 해당하는 profiles 행의 변경을 구독한다.
  /// 구독 해제는 반환된 [StreamSubscription]을 cancel() 하거나
  /// 반환된 [Stream]을 listen 후 cancel 하면 된다.
  ///
  /// 사용 예:
  /// ```dart
  /// final stream = ProfileService().watchPartnerProfile(partnerId);
  /// final sub = stream.listen((profile) { ... });
  /// // 화면 dispose 시
  /// sub.cancel();
  /// ```
  Stream<CoupleProfile?> watchPartnerProfile(String partnerId) {
    // StreamController를 통해 Supabase Realtime 이벤트를 Dart Stream으로 변환
    late StreamController<CoupleProfile?> controller;

    controller = StreamController<CoupleProfile?>(
      onListen: () async {
        // 초기값: 현재 프로필 즉시 emit
        try {
          final initial = await loadPartnerProfile(partnerId);
          if (!controller.isClosed) controller.add(initial);
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }

        // Realtime 구독 설정
        supabase
            .channel('partner_profile_$partnerId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'profiles',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: partnerId,
              ),
              callback: (payload) {
                if (controller.isClosed) return;
                try {
                  final newData =
                      payload.newRecord as Map<String, dynamic>?;
                  if (newData != null) {
                    controller.add(CoupleProfile.fromMap(newData));
                  }
                } catch (e) {
                  controller.addError(e);
                }
              },
            )
            .subscribe();
      },
      onCancel: () {
        supabase.removeChannel(
          supabase.channel('partner_profile_$partnerId'),
        );
        controller.close();
      },
    );

    return controller.stream;
  }
}
