import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../couple/services/couple_service.dart';
import '../onboarding_progress.dart';

class OnboardingStep2Screen extends StatefulWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingStep2Screen({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<OnboardingStep2Screen> createState() => _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState extends State<OnboardingStep2Screen> {
  final _codeController = TextEditingController();
  final _coupleService = CoupleService();

  String? _myCode;
  bool _isLoadingCode = true;
  bool _isConnecting = false;
  bool _connected = false;

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
      if (mounted) setState(() { _myCode = code; _isLoadingCode = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCode = false);
    }
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.length != 6) { _showSnack('6자리 코드를 입력해주세요'); return; }
    setState(() => _isConnecting = true);
    try {
      await _coupleService.connectWithCode(code);
      if (mounted) {
        setState(() { _isConnecting = false; _connected = true; });
        _showSnack('파트너 연결 완료!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) widget.onNext();
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

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingProgress(currentStep: widget.currentStep),
          const SizedBox(height: 40),
          const Text(
            '파트너를 초대해 주세요',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '코드를 공유하거나 파트너 코드를 입력하세요',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),

          // 내 초대 코드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: _isLoadingCode
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    children: [
                      Text(
                        _myCode ?? '------',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('코드 복사'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('또는', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              Expanded(child: Divider()),
            ]),
          ),

          // 파트너 코드 입력
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              letterSpacing: 8, color: AppTheme.primary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700,
                letterSpacing: 8, color: AppTheme.border,
              ),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConnecting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('연결하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),

          const Spacer(),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text(
              '나중에 연결할게요 →',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
