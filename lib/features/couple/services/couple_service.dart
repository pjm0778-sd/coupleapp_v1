import 'dart:math';
import '../../../core/supabase_client.dart';

class CoupleService {
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 내 초대 코드 가져오기 (없으면 새로 생성)
  Future<String> getOrCreateMyCode() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    final existing = await supabase
        .from('couples')
        .select('invite_code')
        .eq('user1_id', userId)
        .isFilter('user2_id', null)
        .maybeSingle();

    if (existing != null) return existing['invite_code'] as String;

    final code = _generateCode();
    await supabase.from('couples').insert({
      'user1_id': userId,
      'invite_code': code,
      'started_at': DateTime.now().toIso8601String().split('T')[0],
    });
    return code;
  }

  /// 파트너 코드로 커플 연결 (DB 함수 호출)
  Future<void> connectWithCode(String code) async {
    await supabase.rpc(
      'connect_couple',
      params: {'p_invite_code': code.trim().toUpperCase()},
    );
    // 연결 성공 후 내 미사용 초대 코드(고아 행) 삭제
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase
          .from('couples')
          .delete()
          .eq('user1_id', userId)
          .isFilter('user2_id', null);
    }
  }

  /// 현재 커플 정보 가져오기
  Future<Map<String, dynamic>?> getCoupleInfo() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();

    final coupleId = profile?['couple_id'];
    if (coupleId == null) return null;

    return await supabase.from('couples').select().eq('id', coupleId).maybeSingle();
  }

  /// 커플 사귄 날짜 업데이트
  Future<void> updateStartedAt(String coupleId, DateTime date) async {
    await supabase
        .from('couples')
        .update({'started_at': date.toIso8601String().split('T')[0]})
        .eq('id', coupleId);
  }

  /// 커플 연결 해제 및 모든 공유 데이터 삭제
  Future<void> disconnectCouple(String coupleId) async {
    await supabase.rpc(
      'disconnect_couple',
      params: {'p_couple_id': coupleId},
    );
  }
}
