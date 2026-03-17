import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../models/transit_result.dart';
import '../services/transport_service.dart';
import '../data/station_codes.dart';

class TransportSearchScreen extends StatefulWidget {
  final String fromStation;
  final String toStation;
  final DateTime? initialDate;

  const TransportSearchScreen({
    super.key,
    required this.fromStation,
    required this.toStation,
    this.initialDate,
  });

  @override
  State<TransportSearchScreen> createState() => _TransportSearchScreenState();
}

class _TransportSearchScreenState extends State<TransportSearchScreen>
    with SingleTickerProviderStateMixin {
  late String _from;
  late String _to;
  late DateTime _date;

  bool _isLoading = false;
  bool _hasSearched = false;
  TransportSearchResult? _result;

  late TabController _tabController;
  final _service = TransportService();

  static const _tabs = ['전체', '기차', '버스'];

  @override
  void initState() {
    super.initState();
    _from = widget.fromStation;
    _to = widget.toStation;
    _date = widget.initialDate ?? DateTime.now();
    _tabController = TabController(length: 3, vsync: this);
    // 초기 자동 검색
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _swapRoute() {
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
      _result = null;
      _hasSearched = false;
    });
    _search();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('ko', 'KR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppTheme.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
        _result = null;
        _hasSearched = false;
      });
      _search();
    }
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.search(
        fromStation: _from,
        toStation: _to,
        date: _date,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _hasSearched = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
          _result = TransportSearchResult(results: [], trainError: e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_date);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('교통편 검색'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── 검색 헤더 ──
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // 출발 ↔ 도착
                Row(
                  children: [
                    Expanded(
                      child: _RouteBox(
                        label: '출발',
                        station: _from,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _swapRoute,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RouteBox(
                        label: '도착',
                        station: _to,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 날짜 선택
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '날짜 변경',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 탭 ──
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
            ),
          ),

          // ── 결과 ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const SizedBox.shrink()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _ResultList(
                            results: _result?.results ?? [],
                            searchResult: _result,
                            filterType: null,
                          ),
                          _ResultList(
                            results: _result?.trainResults ?? [],
                            searchResult: _result,
                            filterType: 'train',
                          ),
                          _ResultList(
                            results: _result?.busResults ?? [],
                            searchResult: _result,
                            filterType: 'bus',
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    final today = DateTime.now();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final tomorrow = today.add(const Duration(days: 1));
    final isTomorrow = d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final suffix = isToday ? ' (오늘)' : isTomorrow ? ' (내일)' : '';
    return '${d.month}월 ${d.day}일 ($wd)$suffix';
  }
}

// ── 출발/도착 박스 ──
class _RouteBox extends StatelessWidget {
  final String label;
  final String station;

  const _RouteBox({required this.label, required this.station});

  @override
  Widget build(BuildContext context) {
    // 역명에서 괄호 부분 분리: "서울역 (KTX)" → "서울역", "(KTX)"
    final match = RegExp(r'^(.*?)\s*(\(.*\))?\s*$').firstMatch(station);
    final name = match?.group(1)?.trim() ?? station;
    final badge = match?.group(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (badge != null)
            Text(
              badge,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

// ── 결과 리스트 ──
class _ResultList extends StatelessWidget {
  final List<TransitResult> results;
  final TransportSearchResult? searchResult;
  final String? filterType; // null=전체, 'train', 'bus'

  const _ResultList({
    required this.results,
    required this.searchResult,
    required this.filterType,
  });

  @override
  Widget build(BuildContext context) {
    if (searchResult?.apiKeyNotConfigured == true) {
      return _InfoCard(
        icon: Icons.vpn_key_outlined,
        title: 'API 키 설정이 필요합니다',
        body: 'lib/core/api_keys.dart 파일에\ndata.go.kr 서비스 키를 입력해 주세요.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // SRT 안내
        if (searchResult?.hasSrtStation == true) ...[
          _SrtBanner(),
          const SizedBox(height: 12),
        ],
        // 에러 배너
        if (searchResult?.trainError != null && filterType != 'bus') ...[
          _ErrorBanner(message: '열차 정보를 불러오지 못했습니다.'),
          const SizedBox(height: 8),
        ],
        if (searchResult?.busError != null && filterType != 'train') ...[
          _ErrorBanner(message: '버스 정보를 불러오지 못했습니다.'),
          const SizedBox(height: 8),
        ],
        // 결과
        if (results.isEmpty)
          const _InfoCard(
            icon: Icons.search_off_rounded,
            title: '검색 결과가 없습니다',
            body: '해당 날짜에 운행 편이 없거나\n노선이 없을 수 있습니다.',
          )
        else
          ...results.map((r) => _TransitCard(result: r)),
      ],
    );
  }
}

// ── SRT 배너 ──
class _SrtBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF003580).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF003580).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.train, size: 18, color: Color(0xFF003580)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SRT는 별도 예매가 필요합니다',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003580)),
                ),
                Text(
                  'SRT 공공 API를 제공하지 않습니다.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _launchUrl(srtBookingUrl),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'SRT 예매',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF003580),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 에러 배너 ──
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 정보 카드 ──
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── 교통편 카드 ──
class _TransitCard extends StatelessWidget {
  final TransitResult result;

  const _TransitCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // 타입 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _typeColor(result.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.typeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _typeColor(result.type),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 시간 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      result.departureTime,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      result.arrivalTime,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  result.durationMinutes > 0 ? result.durationLabel : '소요시간 미제공',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // 가격 + 예매
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.priceLabel,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _launchUrl(
                  result.isRailway ? korailBookingUrl : busBookingUrl,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '예매',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _typeColor(TransitType type) {
    switch (type) {
      case TransitType.ktx:
        return const Color(0xFFE8143C);
      case TransitType.srt:
        return const Color(0xFF003580);
      case TransitType.itx:
        return const Color(0xFF1E8B4F);
      case TransitType.mugunghwa:
        return const Color(0xFFE87A14);
      case TransitType.expressbus:
        return const Color(0xFF9C27B0);
      case TransitType.bus:
        return const Color(0xFF2196F3);
    }
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
