import 'dart:math';
import '../../../core/supabase_client.dart';

class CoupleService {
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// ??珥덈? 肄붾뱶 媛?몄삤湲?(?놁쑝硫??덈줈 ?앹꽦)
  Future<String> getOrCreateMyCode() async {
    final userId = supabase.auth.currentUser!.id;

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

  /// ?뚰듃??肄붾뱶濡?而ㅽ뵆 ?곌껐 (DB ?⑥닔 ?몄텧)
  Future<void> connectWithCode(String code) async {
    await supabase.rpc(
      'connect_couple',
      params: {'p_invite_code': code.trim().toUpperCase()},
    );
  }

  /// ?꾩옱 而ㅽ뵆 ?뺣낫 媛?몄삤湲?
  Future<Map<String, dynamic>?> getCoupleInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .single();

    final coupleId = profile['couple_id'];
    if (coupleId == null) return null;

    return await supabase
        .from('couples')
        .select()
        .eq('id', coupleId)
        .single();
  }

  /// 而ㅽ뵆 ?ш톬 ?좎쭨 ?낅뜲?댄듃
  Future<void> updateStartedAt(String coupleId, DateTime date) async {
    await supabase
        .from('couples')
        .update({'started_at': date.toIso8601String().split('T')[0]})
        .eq('id', coupleId);
  }
}
