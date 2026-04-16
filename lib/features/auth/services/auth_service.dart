import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

class AuthService {
  Map<String, dynamic>? _decodeJwtClaims(String token) {
    if (token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final normalized = base64.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('Failed to decode JWT claims: $error');
      return null;
    }
  }

  void _debugLogJwtClaims(String label, String token) {
    final claims = _decodeJwtClaims(token);
    if (claims == null) return;
    debugPrint('$label claims: ${jsonEncode(claims)}');
  }

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
      try {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'nickname': nickname,
        });
      } catch (_) {
        // Ignore if a trigger already created the profile.
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _signInWithOAuth(
        OAuthProvider.google,
        scopes: 'email profile',
        launchMode: LaunchMode.externalApplication,
      );
      return;
    }

    await _signInWithOAuth(
      OAuthProvider.google,
      scopes: 'email profile',
    );
  }

  Future<void> signInWithApple() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await _signInWithAppleNative();
      return;
    }

    await _signInWithOAuth(
      OAuthProvider.apple,
      scopes: 'name email',
    );
  }

  Future<void> signInWithKakao() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      await _signInWithOAuth(
        OAuthProvider.kakao,
        scopes: 'profile_nickname profile_image',
        launchMode: LaunchMode.externalApplication,
      );
      return;
    }

    await _signInWithOAuth(
      OAuthProvider.kakao,
      scopes: 'profile_nickname profile_image',
    );
  }

  Future<void> _signInWithOAuth(
    OAuthProvider provider, {
    String? scopes,
    LaunchMode? launchMode,
  }) async {
    debugPrint(
      'OAuth start provider=$provider redirect=$supabaseRedirectUrl scopes=$scopes launchMode=${launchMode ?? (kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView)}',
    );

    final didLaunch = await supabase.auth.signInWithOAuth(
      provider,
      redirectTo: supabaseRedirectUrl,
      scopes: scopes,
      authScreenLaunchMode: launchMode ??
          (kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView),
    );

    debugPrint('OAuth launched provider=$provider didLaunch=$didLaunch');

    if (!didLaunch) {
      throw Exception('로그인 화면을 열지 못했습니다.');
    }
  }

  Future<void> _signInWithAppleNative() async {
    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw Exception('이 기기에서는 Apple 로그인을 사용할 수 없습니다.');
    }

    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple identity token을 가져오지 못했습니다.');
    }

    _debugLogJwtClaims('Apple idToken', idToken);
    final claims = _decodeJwtClaims(idToken);
    final tokenNonce = claims?['nonce'];
    final hasTokenNonce = tokenNonce is String && tokenNonce.trim().isNotEmpty;

    if (!hasTokenNonce) {
      debugPrint(
        'Apple idToken is missing nonce claim; proceeding without nonce in Supabase token exchange.',
      );
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: hasTokenNonce ? rawNonce : null,
    );

    final fullName = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .trim();

    if (fullName.isNotEmpty) {
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName,
            'nickname': fullName,
          },
        ),
      );
    }
  }

  Future<void> signOut() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        await supabase
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', uid);
      }
    } catch (_) {}
    await supabase.auth.signOut();
  }

  Future<void> deleteAccount() async {
    await supabase.rpc('delete_user_account');
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // Ignore if the session has already been invalidated.
    }
  }

  Session? get currentSession => supabase.auth.currentSession;
}
