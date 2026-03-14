import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

class AuthService {
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nickname': nickname},
    );

    if (response.user != null) {
      // 트리거가 없을 경우를 대비해 수동으로 프로필 생성 시도
      try {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'nickname': nickname,
        });
      } catch (_) {
        // 이미 트리거에 의해 생성되었다면 무시 가능
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
