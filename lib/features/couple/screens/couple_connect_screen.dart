import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../services/couple_service.dart';
import '../../auth/services/auth_service.dart';

class CoupleConnectScreen extends StatefulWidget {
  const CoupleConnectScreen({super.key});

  @override
  State<CoupleConnectScreen> createState() => _CoupleConnectScreenState();
}

class _CoupleConnectScreenState extends State<CoupleConnectScreen> {
  final _codeController = TextEditingController();
  final _coupleService = CoupleService();
  final _authService = AuthService();

  String? _myCode;
  bool _isLoadingCode = true;
  bool _isConnecting = false;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyCode() async {
    try {
      final code = await _coupleService.getOrCreateMyCode();
      if (mounted) {
        setState(() {
          _myCode = code;
          _isLoadingCode = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCode = false);
    }
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnack('6자리 코드를 입력해주세요');
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await _coupleService.connectWithCode(code);
      if (mounted) {
        _showSnack('커플 연결 완료!');
        setState(() {
          _isConnecting = false;
          _showCelebration = true;
        });
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
        }
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('invalid_code')) {
        _showSnack('유효하지 않거나 이미 사용된 코드입니다');
      } else if (msg.contains('own_code')) {
        _showSnack('자신의 코드는 사용할 수 없습니다');
      } else {
        _showSnack('연결 중 오류가 발생했습니다');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    _showSnack('코드가 복사되었습니다');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('커플 연결'),
        actions: [
          TextButton(
            onPressed: _authService.signOut,
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 애인과 연결하세요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '아래 코드를 내 애인에게 공유하거나\n내 애인의 코드를 입력해 연결하세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // 내 초대 코드
                _buildSectionTitle('내 초대 코드'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [AppTheme.cardShadow],
                  ),
                  child: _isLoadingCode
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Column(
                          children: [
                            // 코드 표시
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: (_myCode ?? '------').split('').map((c) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 40,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.accent),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _copyCode,
                              icon: const Icon(
                                Icons.copy_outlined,
                                size: 16,
                                color: AppTheme.textPrimary,
                              ),
                              label: const Text(
                                '코드 복사',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 28),

                // 파트너 코드 입력 (여기를 내 애인 코드 입력으로 변경)
                _buildSectionTitle('내 애인 코드 입력'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [AppTheme.cardShadow],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                          color: AppTheme.primary,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'XXXXXX',
                          hintStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                            color: AppTheme.border,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isConnecting ? null : _connect,
                          child: _isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '연결하기',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Celebration overlay
          if (_showCelebration)
            _CelebrationOverlay(
              onComplete: () {
                if (mounted) setState(() => _showCelebration = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Celebration overlay
// ---------------------------------------------------------------------------

class _CelebrationOverlay extends StatefulWidget {
  final String? partnerNickname;
  final VoidCallback onComplete;

  const _CelebrationOverlay({
    this.partnerNickname,
    required this.onComplete,
  });

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Pre-defined x offsets (fraction of screen width, 0=left edge, 1=right edge)
  static const List<double> _xFractions = [
    0.05, 0.15, 0.25, 0.38, 0.50, 0.62, 0.72, 0.82, 0.90, 0.97,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 10,
      ),
    ]).animate(_ctrl);

    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white.withOpacity(0.88),
        child: Stack(
          children: [
            // Floating hearts
            for (int i = 0; i < _xFractions.length; i++)
              _FloatingHeart(
                controller: _ctrl,
                xFraction: _xFractions[i],
                screenSize: size,
                delayFraction: i * 0.04,
              ),

            // Center celebration message
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '연결됐어요!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.partnerNickname != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${widget.partnerNickname}님과 함께해요 💕',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual floating heart
// ---------------------------------------------------------------------------

class _FloatingHeart extends StatelessWidget {
  final AnimationController controller;
  final double xFraction;
  final Size screenSize;
  final double delayFraction; // 0..1, start offset within the animation

  const _FloatingHeart({
    required this.controller,
    required this.xFraction,
    required this.screenSize,
    required this.delayFraction,
  });

  @override
  Widget build(BuildContext context) {
    // Each heart travels from below the screen to above it.
    // We use an Interval so hearts start at slightly different times.
    final double begin = delayFraction.clamp(0.0, 0.5);
    final double end = (begin + 0.7).clamp(begin + 0.1, 1.0);

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0),   // start at bottom anchor
      end: const Offset(0, -1),    // slide up by 1x its own height
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    ));

    final fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end),
    ));

    // Vary heart size slightly based on position index
    final double heartSize = 28 + (xFraction * 16).roundToDouble();

    // Absolute x position on screen
    final double xPos = xFraction * screenSize.width - heartSize / 2;

    return Positioned(
      left: xPos,
      bottom: -(heartSize * 2), // anchor point: just off screen bottom
      child: FadeTransition(
        opacity: fadeAnim,
        child: SlideTransition(
          position: slideAnim.drive(
            Tween<Offset>(
              begin: Offset.zero,
              end: Offset(0, -(screenSize.height + heartSize * 4) / heartSize),
            ),
          ),
          child: Text(
            '❤️',
            style: TextStyle(fontSize: heartSize),
          ),
        ),
      ),
    );
  }
}
