import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../data/city_coordinates.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';

class WeatherDetailScreen extends StatefulWidget {
  final DateTime date;
  final String city;
  final String roleLabel;

  const WeatherDetailScreen({
    super.key,
    required this.date,
    required this.city,
    required this.roleLabel,
  });

  @override
  State<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends State<WeatherDetailScreen> {
  final WeatherService _weatherService = WeatherService();

  WeatherData? _summary;
  List<HourlyWeatherData> _hourly = const [];
  String? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == base) return '오늘';
    if (target == base.add(const Duration(days: 1))) return '내일';
    return '${date.year}.${date.month}.${date.day}(${weekdays[date.weekday - 1]})';
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _summary = null;
      _hourly = const [];
      _status = null;
    });

    final date = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDiff = date.difference(today).inDays;

    final city = widget.city.trim();
    if (city.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '지역 설정 필요';
      });
      return;
    }

    if (!cityCoordinates.containsKey(city)) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '도시 재선택 필요';
      });
      return;
    }

    if (dayDiff > 15) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '예보 범위 초과';
      });
      return;
    }

    final summary = await _weatherService.getWeatherForDate(city, date);
    final hourly = await _weatherService.getHourlyWeatherForDate(city, date);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _hourly = hourly ?? const [];
      _status = summary == null && (hourly == null || hourly.isEmpty)
          ? '날씨 정보 없음'
          : null;
      _isLoading = false;
    });
  }

  Widget _buildSummaryPanel() {
    final info = _summary != null ? weatherCodeInfo(_summary!.weatherCode) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _summary != null ? info!.emoji : '🌤',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _summary != null
                      ? '${_summary!.temperature.round()}° · ${info!.label}'
                      : (_status ?? '날씨 정보 없음'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _summary != null
                      ? '습도 ${_summary!.humidity}%'
                      : '시간별 데이터 기준으로 표시돼요',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyRow(HourlyWeatherData item) {
    final info = weatherCodeInfo(item.weatherCode);
    final timeStr =
        '${item.time.hour.toString().padLeft(2, '0')}:00';
    final precipText = item.precipitationProbability != null
        ? '${item.precipitationProbability}%'
        : (item.precipitationMm != null
              ? '${item.precipitationMm!.toStringAsFixed(1)}mm'
              : '-');
    final precipLabel =
        item.precipitationProbability != null ? '강수확률' : '강수량';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(info.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.temperature.round()}° · 습도 ${item.humidity}% · ${info.label}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                precipLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                precipText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.roleLabel} 날씨'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.pageGradient,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              _formatDate(widget.date),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.city,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              _buildSummaryPanel(),
              const SizedBox(height: 14),
              const Text(
                '시간별 상세',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (_hourly.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    _status ?? '시간별 데이터가 없어요.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ..._hourly.map(_buildHourlyRow),
            ],
          ],
        ),
      ),
    );
  }
}
