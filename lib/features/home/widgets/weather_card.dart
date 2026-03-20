import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../data/city_coordinates.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  final String? myCity;
  final String? partnerCity;
  final String? partnerNickname;
  final VoidCallback? onSetupTap; // 위치 미설정 시 설정 화면 이동

  const WeatherCard({
    super.key,
    this.myCity,
    this.partnerCity,
    this.partnerNickname,
    this.onSetupTap,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  final _service = WeatherService();
  WeatherData? _myWeather;
  WeatherData? _partnerWeather;
  bool _loading = true;
  bool _hasError = false;

  // 파트너 도시가 내 도시와 다를 때만 별도 표시
  bool get _showBoth =>
      widget.partnerCity != null &&
      widget.partnerCity!.isNotEmpty &&
      widget.partnerCity != widget.myCity;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myCity != widget.myCity ||
        oldWidget.partnerCity != widget.partnerCity) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (widget.myCity == null || widget.myCity!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() { _loading = true; _hasError = false; });

    try {
      final results = await Future.wait([
        _service.getWeather(widget.myCity!),
        if (_showBoth) _service.getWeather(widget.partnerCity!),
      ]);
      if (mounted) {
        setState(() {
          _myWeather = results[0];
          _partnerWeather = _showBoth && results.length > 1 ? results[1] : null;
          _loading = false;
          _hasError = _myWeather == null;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: Color(0xFF1976D2),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 날씨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (!_loading && !_hasError && _myWeather != null)
                  GestureDetector(
                    onTap: _fetch,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // ── 콘텐츠 ──────────────────────────────────
          if (widget.myCity == null || widget.myCity!.isEmpty)
            _buildNoCity()
          else if (_loading)
            _buildLoading()
          else if (_hasError)
            _buildError()
          else if (_showBoth)
            _buildTwoPanel()
          else
            _buildOnePanel(_myWeather, '나'),
        ],
      ),
    );
  }

  // ── 날씨 도시 미설정 ──────────────────────────────────
  Widget _buildNoCity() {
    return GestureDetector(
      onTap: widget.onSetupTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('🌍', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              const Text(
                '날씨를 보려면 위치를 설정해 보세요',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              if (widget.onSetupTap != null) ...[
                const SizedBox(height: 4),
                const Text(
                  '설정 → 날씨 위치',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 로딩 ───────────────────────────────────────────
  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // ── 에러 ───────────────────────────────────────────
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: GestureDetector(
        onTap: _fetch,
        child: const Text(
          '날씨 정보를 불러오지 못했어요  🔄',
          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
        ),
      ),
    );
  }

  // ── 한 도시 ────────────────────────────────────────
  Widget _buildOnePanel(WeatherData? data, String label) {
    if (data == null) return _buildError();
    final info = weatherCodeInfo(data.weatherCode);
    final temp = data.temperature.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.city,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$temp°',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '습도 ${data.humidity}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 두 도시 ────────────────────────────────────────
  Widget _buildTwoPanel() {
    final partnerName = widget.partnerNickname ?? '파트너';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _buildCityTile(_myWeather, '나')),
            Container(
              width: 1,
              color: AppTheme.border,
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            Expanded(child: _buildCityTile(_partnerWeather, partnerName)),
          ],
        ),
      ),
    );
  }

  Widget _buildCityTile(WeatherData? data, String label) {
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Text('정보 없음',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
        ),
      );
    }
    final info = weatherCodeInfo(data.weatherCode);
    final temp = data.temperature.round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 이모지
          Text(info.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          // 도시명
          Text(
            data.city,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 온도 + 날씨
          Row(
            children: [
              Text(
                '$temp°',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  info.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 습도
          Text(
            '습도 ${data.humidity}%',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
