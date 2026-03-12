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
    if (code.length != 6) {
      _showSnack('6?먮━ 肄붾뱶瑜??낅젰?댁＜?몄슂');
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await _coupleService.connectWithCode(code);
      if (mounted) {
        _showSnack('而ㅽ뵆 ?곌껐 ?꾨즺!');
        // ?곌껐 ?????ъ떆??(AppRouter媛 MainShell濡??꾪솚)
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
        }
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('invalid_code')) {
        _showSnack('?좏슚?섏? ?딄굅???대? ?ъ슜??肄붾뱶?덉슂');
      } else if (msg.contains('own_code')) {
        _showSnack('?먯떊??肄붾뱶???ъ슜?????놁뼱??);
      } else {
        _showSnack('?곌껐 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    _showSnack('肄붾뱶媛 蹂듭궗?먯뼱??);
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
        title: const Text('而ㅽ뵆 ?곌껐'),
        actions: [
          TextButton(
            onPressed: _authService.signOut,
            child: const Text(
              '濡쒓렇?꾩썐',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '?뚰듃?덉? ?곌껐?섏꽭??,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '?꾨옒 肄붾뱶瑜??뚰듃?덉뿉寃?怨듭쑀?섍굅??n?뚰듃?덉쓽 肄붾뱶瑜??낅젰???곌껐?섏꽭??,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),

            // ??珥덈? 肄붾뱶 ?뱀뀡
            _buildSectionTitle('??珥덈? 肄붾뱶'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: _isLoadingCode
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : Column(
                      children: [
                        // 肄붾뱶 ?쒖떆
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: (_myCode ?? '------').split('').map((c) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 40,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
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
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_outlined,
                              size: 16, color: AppTheme.textPrimary),
                          label: const Text('肄붾뱶 蹂듭궗',
                              style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 28),

            // ?뚰듃??肄붾뱶 ?낅젰 ?뱀뀡
            _buildSectionTitle('?뚰듃??肄붾뱶 ?낅젰'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
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
                      hintStyle: TextStyle(
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
                            color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isConnecting ? null : _connect,
                      child: _isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('?곌껐?섍린',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
