import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

enum _SocialLoginProvider { google, apple, kakao }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showEmailForm = false;

  bool get _showAppleLogin {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e, stackTrace) {
      debugPrint('Email login failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithProvider(_SocialLoginProvider provider) async {
    setState(() => _isLoading = true);

    try {
      switch (provider) {
        case _SocialLoginProvider.google:
          await _authService.signInWithGoogle();
        case _SocialLoginProvider.apple:
          await _authService.signInWithApple();
        case _SocialLoginProvider.kakao:
          await _authService.signInWithKakao();
      }
    } catch (e, stackTrace) {
      debugPrint('Social login failed ($provider): $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e.toString(), provider: provider)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error, {_SocialLoginProvider? provider}) {
    final cleanedError = error
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();

    if (error.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 틀렸습니다.';
    }
    if (error.contains('Email not confirmed')) return '이메일 인증을 완료해주세요.';
    if (error.contains('Google 로그인이 취소되었습니다')) {
      return 'Google 로그인이 취소되었습니다.';
    }
    if (error.contains('Google identity token을 가져오지 못했습니다')) {
      return 'Google 인증 토큰을 가져오지 못했습니다. Google Cloud의 iOS/Web 클라이언트 설정을 확인해주세요.';
    }
    if (error.contains(
      'Passed nonce and nonce in id_token should either both exist or not',
    )) {
      if (provider == _SocialLoginProvider.google) {
        return 'Google 로그인 토큰 검증 중 nonce 불일치가 발생했습니다. 앱 설정을 수정했으니 다시 시도해주세요.';
      }
      if (provider == _SocialLoginProvider.apple) {
        return 'Apple 로그인 토큰 검증 중 nonce 불일치가 발생했습니다. 최신 설정으로 다시 시도해주세요.';
      }
      return '소셜 로그인 토큰 검증 중 nonce 불일치가 발생했습니다.';
    }
    if (error.contains('Unacceptable audience in id_token') ||
        error.contains('invalid audience') ||
        error.contains('audience')) {
      return 'Supabase Google provider의 Client ID 설정이 앱과 일치하지 않습니다. 콘솔 설정을 확인해주세요.';
    }
    if (error.contains('로그인 화면을 열지 못했습니다')) {
      return '외부 로그인 화면을 열지 못했습니다.';
    }
    if (cleanedError.isNotEmpty && cleanedError.length <= 140) {
      return cleanedError;
    }
    return '로그인 중 오류가 발생했습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: AppTheme.pageGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),

                    // 아이콘 뱃지
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 28,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 앱 이름
                    Text(
                      '커플듀티',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Couple Duty',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.primary,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '둘의 오늘과 내일을 우리의 일정으로',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 구분선
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.border,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.border,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 소셜 로그인 버튼 ──
                    _buildSocialButton(
                      provider: _SocialLoginProvider.google,
                      label: 'Google로 계속하기',
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textPrimary,
                      borderColor: AppTheme.border,
                    ),
                    const SizedBox(height: 12),

                    if (_showAppleLogin) ...[
                      _buildSocialButton(
                        provider: _SocialLoginProvider.apple,
                        label: 'Apple로 계속하기',
                        backgroundColor: AppTheme.textPrimary,
                        foregroundColor: Colors.white,
                        borderColor: AppTheme.textPrimary,
                      ),
                      const SizedBox(height: 12),
                    ],

                    _buildSocialButton(
                      provider: _SocialLoginProvider.kakao,
                      label: 'KakaoTalk으로 계속하기',
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xFF191919),
                      borderColor: Colors.transparent,
                    ),
                    const SizedBox(height: 12),

                    // ── 이메일 로그인 버튼 ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _showEmailForm
                                ? AppTheme.primary
                                : AppTheme.border,
                          ),
                          foregroundColor: _showEmailForm
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: _showEmailForm
                              ? AppTheme.primaryLight
                              : AppTheme.surface,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _showEmailForm = !_showEmailForm),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text(
                          '이메일로 로그인',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // ── 이메일 폼 (펼침) ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: _showEmailForm
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                _buildLabel('이메일'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _emailController,
                                  hint: 'example@email.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return '이메일을 입력해주세요';
                                    if (!v.contains('@'))
                                      return '올바른 이메일 형식이 아닙니다';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildLabel('비밀번호'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: '6자 이상',
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return '비밀번호를 입력해주세요';
                                    if (v.length < 6)
                                      return '6자 이상 입력해주세요';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _isLoading ? null : _login,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            '로그인',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '아직 계정이 없으신가요?',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SignupScreen(),
                                        ),
                                      ),
                                      child: const Text(
                                        '회원가입',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 32),

                    // 약관 안내
                    Center(
                      child: Text(
                        '계속하면 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주됩니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 1.8,
        height: 1.0,
      ),
    );
  }

  Widget _buildSocialButton({
    required _SocialLoginProvider provider,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required Color borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
        ),
        onPressed: _isLoading ? null : () => _loginWithProvider(provider),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(provider, foregroundColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(
    _SocialLoginProvider provider,
    Color foregroundColor,
  ) {
    switch (provider) {
      case _SocialLoginProvider.google:
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4285F4),
            ),
          ),
        );
      case _SocialLoginProvider.apple:
        return Icon(Icons.apple, color: foregroundColor, size: 20);
      case _SocialLoginProvider.kakao:
        return Icon(
          Icons.chat_bubble_rounded,
          color: foregroundColor,
          size: 18,
        );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      decoration: AppTheme.textFieldDecoration(
        hint: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
