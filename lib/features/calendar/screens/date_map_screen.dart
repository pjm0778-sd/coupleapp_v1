import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_detail.dart';

class DateMapScreen extends StatefulWidget {
  final String coupleId;
  final String myUserId;

  const DateMapScreen({
    super.key,
    required this.coupleId,
    required this.myUserId,
  });

  @override
  State<DateMapScreen> createState() => _DateMapScreenState();
}

enum _ViewMode { all, monthly }

class _DateMapScreenState extends State<DateMapScreen> {
  final _service = ScheduleService();
  final _mapController = MapController();

  List<Schedule> _allSchedules = []; // 전체 캐시 (couple + 위치 있는 것)
  bool _loading = true;
  Schedule? _selected;

  _ViewMode _viewMode = _ViewMode.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getSchedulesWithLocation(widget.coupleId);
    // 우리 공동 일정(ownerType == 'couple')만 필터
    final coupleOnly = list.where((s) => s.ownerType == 'couple').toList();
    if (mounted) {
      setState(() {
        _allSchedules = coupleOnly;
        _loading = false;
      });
    }
  }

  /// 현재 뷰 모드에 따라 표시할 일정 목록
  List<Schedule> get _visibleSchedules {
    if (_viewMode == _ViewMode.all) return _allSchedules;
    return _allSchedules.where((s) {
      final d = s.startDate ?? s.date;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();
  }

  Color _pinColor(Schedule s) {
    switch (s.category) {
      case '데이트': return const Color(0xFFE91E63);
      case '여행':  return const Color(0xFFFF9800);
      case '약속':  return const Color(0xFF2196F3);
      default:      return AppTheme.primary;
    }
  }

  bool _isVisited(Schedule s) {
    final today = DateTime.now();
    final date = s.endDate ?? s.startDate ?? s.date;
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  LatLng get _initialCenter {
    final list = _visibleSchedules;
    if (list.isEmpty) return const LatLng(37.5665, 126.9780);
    return LatLng(list.first.latitude!, list.first.longitude!);
  }

  void _prevMonth() => setState(() {
        _selected = null;
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _selected = null;
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      });

  @override
  Widget build(BuildContext context) {
    final visible = _visibleSchedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('우리 장소 지도'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 뷰 모드 토글 + 월 네비게이션 ──
                _buildTopBar(),
                const Divider(height: 1),

                // ── 지도 ──
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined,
                                  size: 56, color: AppTheme.textSecondary),
                              const SizedBox(height: 12),
                              Text(
                                _viewMode == _ViewMode.monthly
                                    ? '${_selectedMonth.year}년 ${_selectedMonth.month}월에\n장소가 등록된 우리 일정이 없어요'
                                    : '장소가 등록된 우리 일정이 없어요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _initialCenter,
                                initialZoom: 12,
                                onTap: (tapPos, point) =>
                                    setState(() => _selected = null),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.coupleduty.app',
                                ),
                                MarkerLayer(
                                  markers: visible.map((s) {
                                    final isSelected = _selected?.id == s.id;
                                    final visited = _isVisited(s);
                                    final color = _pinColor(s);
                                    return Marker(
                                      point: LatLng(s.latitude!, s.longitude!),
                                      width: isSelected ? 200 : 40,
                                      height: isSelected ? 72 : 40,
                                      alignment: Alignment.topCenter,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selected = s);
                                          _mapController.move(
                                            LatLng(s.latitude!, s.longitude!),
                                            14,
                                          );
                                        },
                                        child: isSelected
                                            ? _SelectedMarker(
                                                schedule: s,
                                                color: color,
                                                visited: visited,
                                              )
                                            : Icon(
                                                visited
                                                    ? Icons.location_on
                                                    : Icons.flag,
                                                color: color,
                                                size: 40,
                                              ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),

                            // 범례
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 2))
                                  ],
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 16, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text('다녀온 곳',
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flag,
                                            size: 16, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text('계획 중',
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 선택된 일정 카드
                            if (_selected != null)
                              Positioned(
                                bottom: 24,
                                left: 16,
                                right: 16,
                                child: _ScheduleCard(
                                  schedule: _selected!,
                                  onDetail: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScheduleDetailScreen(
                                            schedule: _selected!),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            // 장소 수 (선택 없을 때)
                            if (_selected == null)
                              Positioned(
                                bottom: 24,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '장소 ${visible.length}곳',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 전체 / 월별 토글
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeTab(
                  label: '전체',
                  selected: _viewMode == _ViewMode.all,
                  onTap: () => setState(() {
                    _viewMode = _ViewMode.all;
                    _selected = null;
                  }),
                ),
                _ModeTab(
                  label: '월별',
                  selected: _viewMode == _ViewMode.monthly,
                  onTap: () => setState(() {
                    _viewMode = _ViewMode.monthly;
                    _selected = null;
                  }),
                ),
              ],
            ),
          ),

          // 월 네비게이션 (월별 모드일 때만)
          if (_viewMode == _ViewMode.monthly) ...[
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Text(
              '${_selectedMonth.year}년 ${_selectedMonth.month}월',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 모드 탭 버튼 ──
class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── 선택된 핀 말풍선 ──
class _SelectedMarker extends StatelessWidget {
  final Schedule schedule;
  final Color color;
  final bool visited;

  const _SelectedMarker({
    required this.schedule,
    required this.color,
    required this.visited,
  });

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '';
    final dateStr =
        '${schedule.date.year}.${schedule.date.month.toString().padLeft(2, '0')}.${schedule.date.day.toString().padLeft(2, '0')}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              Text(dateStr,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        Icon(
          visited ? Icons.location_on : Icons.flag,
          color: color,
          size: 24,
        ),
      ],
    );
  }
}

// ── 하단 일정 카드 ──
class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onDetail;

  const _ScheduleCard({required this.schedule, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '';
    final dateStr =
        '${schedule.date.year}.${schedule.date.month.toString().padLeft(2, '0')}.${schedule.date.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(schedule.location ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onDetail,
            child: const Text('상세보기'),
          ),
        ],
      ),
    );
  }
}
