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
    // 자동 검색 제거 — 유저가 검색 버튼을 눌러야 조회됨
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 파라미터가 바뀌었지만 아직 검색하지 않은 상태
  bool _isDirty = false;

  void _swapRoute() {
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
      _isDirty = true;
    });
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
        _isDirty = true;
      });
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
            _isDirty = true;
          });
        },
      ),
    );
  }

  Future<void> _search() async {
    setState(() { _isLoading = true; _isDirty = false; });
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
                // 날짜 + 검색 버튼 행
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
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
                              const Icon(Icons.chevron_right,
                                  size: 18, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 검색 버튼 (_isDirty 시 강조)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _isDirty
                            ? AppTheme.primary
                            : AppTheme.primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isDirty
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _search,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_rounded,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 4),
                                const Text('검색',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    ? const _InfoCard(
                        icon: Icons.train_outlined,
                        title: '검색 버튼을 눌러주세요',
                        body: '출발지, 도착지, 날짜를 선택한 뒤\n검색 버튼을 눌러 조회하세요.',
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _ResultList(
                              results: _result?.results ?? [],
                              searchResult: _result,
                              filterType: null,
                              fromStation: _from,
                              toStation: _to,
                              date: _date),
                          _ResultList(
                              results: _result?.trainResults ?? [],
                              searchResult: _result,
                              filterType: 'train',
                              fromStation: _from,
                              toStation: _to,
                              date: _date),
                          _ResultList(
                              results: _result?.busResults ?? [],
                              searchResult: _result,
                              filterType: 'bus',
                              fromStation: _from,
                              toStation: _to,
                              date: _date),
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

// ── 역 검색 시트 (검색 + 지역 선택 탭) ──
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

class _StationSearchSheetState extends State<_StationSearchSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // 지역 선택 상태
  String? _province;
  String? _city;

  static final _allStations = cityStations.entries
      .where((e) => e.value.isNotEmpty)
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _select(String station) {
    Navigator.pop(context);
    widget.onSelected(station);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 타이틀 + 닫기
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(widget.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 탭바
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: '검색'), Tab(text: '지역 선택')],
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2.5,
          ),
          const Divider(height: 1),
          // 탭뷰
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSearchTab(), _buildRegionTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 검색 탭 ───
  Widget _buildSearchTab() {
    final filtered = _filtered;
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            autofocus: false,
            decoration: InputDecoration(
              hintText: '역명, 터미널, 도시명으로 검색',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty ? '전체 ${filtered.length}개' : '검색결과 ${filtered.length}개',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ),
        const Divider(height: 1),
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
                    final excluded = e.station == widget.excludeStation;
                    return _StationItem(
                      entry: e,
                      isExcluded: excluded,
                      onTap: excluded ? null : () => _select(e.station),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── 지역 선택 탭 ───
  Widget _buildRegionTab() {
    return Column(
      children: [
        // 도/광역시 칩 행
        _ProvinceChips(
          selected: _province,
          onSelect: (p) => setState(() {
            _province = p;
            _city = null;
          }),
        ),
        const Divider(height: 1),
        Expanded(
          child: _province == null
              ? _buildProvinceHint()
              : _city == null
                  ? _buildCityList(_province!)
                  : _buildStationList(_city!),
        ),
      ],
    );
  }

  Widget _buildProvinceHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 52,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('위에서 도/광역시를 선택하세요',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // 시/군 목록 (cityStations에 등록된 곳만)
  Widget _buildCityList(String province) {
    final cities = getCitiesInProvince(province)
        .where((c) => cityStations.containsKey(c))
        .toList();

    if (cities.isEmpty) {
      return const Center(
        child: Text('등록된 역/터미널이 없습니다',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: cities.length,
      itemBuilder: (_, i) {
        final city = cities[i];
        final stations = cityStations[city]!;
        final subtitle = stations
            .map((s) => s.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim())
            .join(' · ');

        return InkWell(
          onTap: () {
            if (stations.length == 1) {
              final st = stations.first;
              if (st != widget.excludeStation) _select(st);
            } else {
              setState(() => _city = city);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      city.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(city,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(
                  stations.length > 1
                      ? Icons.chevron_right
                      : Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 역/터미널 목록 (시 선택 후)
  Widget _buildStationList(String city) {
    final stations = cityStations[city] ?? [];
    return Column(
      children: [
        // 뒤로가기 헤더
        InkWell(
          onTap: () => setState(() => _city = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(city,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
                const SizedBox(width: 6),
                const Text('역/터미널 선택',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: stations.length,
            itemBuilder: (_, i) {
              final st = stations[i];
              final entry = _StationEntry(city: city, station: st);
              final excluded = st == widget.excludeStation;
              return _StationItem(
                entry: entry,
                isExcluded: excluded,
                onTap: excluded ? null : () => _select(st),
              );
            },
          ),
        ),
      ],
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

// ── 도/광역시 칩 선택 ──
class _ProvinceChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ProvinceChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provinces = getProvinces();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: provinces.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = provinces[i];
          final active = p == selected;
          return GestureDetector(
            onTap: () => onSelect(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppTheme.primary : AppTheme.border,
                ),
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 결과 리스트 ──
class _ResultList extends StatelessWidget {
  final List<TransitResult> results;
  final TransportSearchResult? searchResult;
  final String? filterType;
  final String fromStation;
  final String toStation;
  final DateTime date;

  const _ResultList({
    required this.results,
    required this.searchResult,
    required this.filterType,
    required this.fromStation,
    required this.toStation,
    required this.date,
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
          ...results.map((r) => _TransitCard(
                result: r,
                fromStation: fromStation,
                toStation: toStation,
                date: date,
              )),
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
  final String fromStation;
  final String toStation;
  final DateTime date;

  const _TransitCard({
    required this.result,
    required this.fromStation,
    required this.toStation,
    required this.date,
  });

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
            onTap: () => _openBooking(),
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

  String _bookingUrl() {
    if (result.type == TransitType.srt) {
      return buildSrtBookingUrl(
        fromStation: fromStation,
        toStation: toStation,
        date: date,
        departureTime: result.departureTime,
      );
    }
    if (result.isRailway) {
      return buildKorailBookingUrl(
            fromStation: fromStation,
            toStation: toStation,
            date: date,
            departureTime: result.departureTime,
          ) ??
          korailBookingUrl;
    }
    return result.isIntercityBus ? intercityBusBookingUrl : busBookingUrl;
  }

  /// 예매 페이지 열기: 앱 설치 확인 후 앱으로, 미설치 시 브라우저로 이동
  Future<void> _openBooking() async {
    final webUrl = _bookingUrl();

    // 앱 custom scheme 시도 (설치돼 있으면 앱으로 열림)
    final appScheme = result.type == TransitType.srt
        ? 'korail' // SRT 앱 scheme (패키지 com.srail.www)
        : result.type == TransitType.ktx || result.isRailway
            ? 'korailapp'
            : null;

    if (appScheme != null) {
      final appUri = Uri.parse('$appScheme://');
      try {
        if (await canLaunchUrl(appUri)) {
          // 앱이 설치돼 있음 — 앱 실행 후 웹 URL도 함께 열기
          await launchUrl(Uri.parse(webUrl),
              mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // 앱 미설치 or 버스 계열: 브라우저로 웹 예매 페이지 열기
    await _launchUrl(webUrl);
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
  // 외부 브라우저 우선, 실패 시 인앱 웹뷰로 폴백
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // 최후 수단: 인앱 웹뷰
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}
