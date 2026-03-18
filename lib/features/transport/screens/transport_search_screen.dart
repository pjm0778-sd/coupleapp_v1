import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../profile/data/city_station_data.dart';
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

  @override
  void initState() {
    super.initState();
    _from = widget.fromStation;
    _to = widget.toStation;
    _date = widget.initialDate ?? DateTime.now();
    _tabController = TabController(length: 3, vsync: this);
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

  void _showStationPicker({required bool isDeparture}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationSearchSheet(
        title: isDeparture ? '출발지 선택' : '도착지 선택',
        excludeStation: isDeparture ? _to : _from,
        onSelected: (station) {
          setState(() {
            if (isDeparture) {
              _from = station;
            } else {
              _to = station;
            }
            _result = null;
            _hasSearched = false;
          });
          _search();
        },
      ),
    );
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
                        onTap: () => _showStationPicker(isDeparture: true),
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
                        onTap: () => _showStationPicker(isDeparture: false),
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
                          _formatDate(_date),
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
              tabs: const [Tab(text: '전체'), Tab(text: '기차'), Tab(text: '버스')],
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
                              filterType: null),
                          _ResultList(
                              results: _result?.trainResults ?? [],
                              searchResult: _result,
                              filterType: 'train'),
                          _ResultList(
                              results: _result?.busResults ?? [],
                              searchResult: _result,
                              filterType: 'bus'),
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

// ── 출발/도착 박스 (탭 가능) ──
class _RouteBox extends StatelessWidget {
  final String label;
  final String station;
  final VoidCallback onTap;

  const _RouteBox({
    required this.label,
    required this.station,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(.*?)\s*(\(.*\))?\s*$').firstMatch(station);
    final name = match?.group(1)?.trim() ?? station;
    final badge = match?.group(2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (badge != null)
                    Text(badge,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── 역 검색 시트 ──
class _StationSearchSheet extends StatefulWidget {
  final String title;
  final String excludeStation;
  final ValueChanged<String> onSelected;

  const _StationSearchSheet({
    required this.title,
    required this.excludeStation,
    required this.onSelected,
  });

  @override
  State<_StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<_StationSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // 전체 역 목록: city → [station, ...]
  static final _allStations = cityStations.entries
      .where((e) => e.key != '직접 입력' && e.value.isNotEmpty)
      .expand((e) => e.value.map((s) => _StationEntry(city: e.key, station: s)))
      .toList();

  List<_StationEntry> get _filtered {
    if (_query.isEmpty) return _allStations;
    final q = _query.toLowerCase();
    return _allStations
        .where((e) =>
            e.city.contains(q) ||
            e.station.toLowerCase().contains(q) ||
            e.stationShort.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // 타이틀
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '역명, 터미널, 도시명으로 검색',
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppTheme.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.clear,
                            size: 18, color: AppTheme.textSecondary),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          // 결과 카운트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _query.isEmpty ? '전체 ${filtered.length}개' : '검색결과 ${filtered.length}개',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // 목록
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('검색 결과가 없습니다',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final isExcluded = e.station == widget.excludeStation;
                      return _StationItem(
                        entry: e,
                        isExcluded: isExcluded,
                        onTap: isExcluded
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onSelected(e.station);
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StationEntry {
  final String city;
  final String station;

  const _StationEntry({required this.city, required this.station});

  // 괄호 제거한 역명: "서울역 (KTX)" → "서울역"
  String get stationShort =>
      station.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

  // 타입 뱃지 색상
  Color get badgeColor {
    if (station.contains('KTX')) return const Color(0xFFE8143C);
    if (station.contains('SRT')) return const Color(0xFF003580);
    if (station.contains('ITX') || station.contains('새마을')) {
      return const Color(0xFF1E8B4F);
    }
    if (station.contains('공항')) return const Color(0xFF00ACC1);
    return const Color(0xFF2196F3); // 버스/터미널
  }

  String get badgeLabel {
    if (station.contains('KTX')) return 'KTX';
    if (station.contains('SRT')) return 'SRT';
    if (station.contains('ITX')) return 'ITX';
    if (station.contains('공항')) return '공항';
    if (station.contains('터미널') || station.contains('터미날')) return '버스';
    return '기차';
  }
}

class _StationItem extends StatelessWidget {
  final _StationEntry entry;
  final bool isExcluded;
  final VoidCallback? onTap;

  const _StationItem({
    required this.entry,
    required this.isExcluded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: isExcluded ? 0.35 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              // 타입 뱃지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: entry.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: entry.badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 역명
              Expanded(
                child: Text(
                  entry.stationShort,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              // 도시
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.city,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 결과 리스트 ──
class _ResultList extends StatelessWidget {
  final List<TransitResult> results;
  final TransportSearchResult? searchResult;
  final String? filterType;

  const _ResultList({
    required this.results,
    required this.searchResult,
    required this.filterType,
  });

  @override
  Widget build(BuildContext context) {
    if (searchResult == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (searchResult?.hasSrtStation == true) ...[
          _SrtBanner(),
          const SizedBox(height: 12),
        ],
        if (searchResult?.trainError != null && filterType != 'bus') ...[
          _ErrorBanner(message: searchResult!.trainError!),
          const SizedBox(height: 8),
        ],
        if (searchResult?.busError != null && filterType != 'train') ...[
          _ErrorBanner(message: searchResult!.busError!),
          const SizedBox(height: 8),
        ],
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

class _SrtBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF003580).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF003580).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 15, color: Color(0xFF003580)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'SRT 시간표는 참고용입니다. 예매는 SRT 앱·홈페이지에서 해주세요.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _launchUrl(srtBookingUrl),
            style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero),
            child: const Text('예매',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF003580),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

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
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(icon,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5)),
        ],
      ),
    );
  }
}

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _typeColor(result.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(result.typeLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _typeColor(result.type))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(result.departureTime,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(result.arrivalTime,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                        result.durationMinutes > 0
                            ? result.durationLabel
                            : '소요시간 미제공',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    if (result.fareLabel.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      Text(result.fareLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _launchUrl(
                result.type == TransitType.srt
                    ? srtBookingUrl
                    : result.isRailway
                        ? korailBookingUrl
                        : result.isIntercityBus
                            ? intercityBusBookingUrl
                            : busBookingUrl),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('예매',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
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
      case TransitType.intercitybus:
        return const Color(0xFF00897B); // teal
    }
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
