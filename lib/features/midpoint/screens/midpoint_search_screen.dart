import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/midpoint_input.dart';
import '../services/midpoint_service.dart';
import '../widgets/origin_input_widget.dart';
import '../widgets/transport_selector_widget.dart';
import 'midpoint_result_screen.dart';

class MidpointSearchScreen extends StatefulWidget {
  const MidpointSearchScreen({super.key});

  @override
  State<MidpointSearchScreen> createState() => _MidpointSearchScreenState();
}

class _MidpointSearchScreenState extends State<MidpointSearchScreen> {
  final _service = MidpointService();

  String _myOrigin = '';
  String _partnerOrigin = '';
  TransportMode _myMode = TransportMode.publicTransit;
  CarType _myCarType = CarType.normal;
  TransportMode _partnerMode = TransportMode.publicTransit;
  CarType _partnerCarType = CarType.normal;
  DateTheme _theme = DateTheme.date;
  bool _loading = false;

  bool get _canSearch =>
      _myOrigin.isNotEmpty && _partnerOrigin.isNotEmpty;

  Future<void> _search() async {
    if (!_canSearch) return;

    setState(() => _loading = true);

    try {
      final input = MidpointSearchInput(
        myOrigin: _myOrigin,
        partnerOrigin: _partnerOrigin,
        myMode: _myMode,
        myCarType: _myMode == TransportMode.car ? _myCarType : null,
        partnerMode: _partnerMode,
        partnerCarType: _partnerMode == TransportMode.car ? _partnerCarType : null,
        theme: _theme,
      );

      final results = await _service.search(input);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MidpointResultScreen(
            results: results,
            input: input,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[400]),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
        title: const Text('중간지점 찾기',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 출발지 ──
            _SectionCard(
              title: '출발지',
              child: Column(
                children: [
                  OriginInputWidget(
                    label: '내 출발지',
                    hint: '예) 서울 강남구',
                    onSelected: (v) => setState(() => _myOrigin = v),
                  ),
                  const SizedBox(height: 16),
                  OriginInputWidget(
                    label: '상대방 출발지',
                    hint: '예) 부산 해운대구',
                    onSelected: (v) => setState(() => _partnerOrigin = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 교통수단 ──
            _SectionCard(
              title: '교통수단',
              child: Column(
                children: [
                  TransportSelectorWidget(
                    label: '내 교통수단',
                    selectedMode: _myMode,
                    selectedCarType: _myCarType,
                    onModeChanged: (m) => setState(() => _myMode = m),
                    onCarTypeChanged: (t) => setState(() => _myCarType = t),
                  ),
                  const SizedBox(height: 16),
                  TransportSelectorWidget(
                    label: '상대방 교통수단',
                    selectedMode: _partnerMode,
                    selectedCarType: _partnerCarType,
                    onModeChanged: (m) => setState(() => _partnerMode = m),
                    onCarTypeChanged: (t) => setState(() => _partnerCarType = t),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 테마 ──
            _SectionCard(
              title: '테마',
              child: Row(
                children: DateTheme.values
                    .map((t) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: t == DateTheme.values.last ? 0 : 8),
                            child: _ThemeButton(
                              theme: t,
                              selected: _theme == t,
                              onTap: () => setState(() => _theme = t),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 28),

            // ── 검색 버튼 ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _canSearch && !_loading ? _search : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('중간지점 찾기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final DateTheme theme;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    DateTheme.date: '💑',
    DateTheme.travel: '✈️',
    DateTheme.simple: '📍',
  };

  const _ThemeButton(
      {required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.12) : AppTheme.background,
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(_icons[theme]!, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              theme.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
