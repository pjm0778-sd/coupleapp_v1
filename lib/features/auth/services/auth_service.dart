import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

class AuthService {
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nickname': nickname},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
