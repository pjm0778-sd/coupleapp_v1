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

class _DateMapScreenState extends State<DateMapScreen> {
  final _service = ScheduleService();
  final _mapController = MapController();

  List<Schedule> _schedules = [];
  bool _loading = true;
  Schedule? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getSchedulesWithLocation(widget.coupleId);
    if (mounted) setState(() { _schedules = list; _loading = false; });
  }

  Color _pinColor(Schedule s) {
    switch (s.category) {
      case '데이트': return const Color(0xFFE91E63);
      case '여행':  return const Color(0xFFFF9800);
      case '약속':  return const Color(0xFF2196F3);
      case '근무':  return const Color(0xFF4CAF50);
      default:      return AppTheme.primary;
    }
  }

  LatLng get _initialCenter {
    if (_schedules.isEmpty) return const LatLng(37.5665, 126.9780); // 서울
    return LatLng(_schedules.first.latitude!, _schedules.first.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 지도'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off_outlined,
                          size: 56, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text(
                        '장소가 등록된 일정이 없어요',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '일정 추가 시 장소를 검색해보세요',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                        onTap: (tapPos, point) => setState(() => _selected = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.coupleduty.app',
                        ),
                        MarkerLayer(
                          markers: _schedules.map((s) {
                            final isSelected = _selected?.id == s.id;
                            return Marker(
                              point: LatLng(s.latitude!, s.longitude!),
                              width: isSelected ? 200 : 40,
                              height: isSelected ? 64 : 40,
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
                                    ? _SelectedMarker(schedule: s, color: _pinColor(s))
                                    : Icon(Icons.location_on,
                                        color: _pinColor(s), size: 40),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // 선택된 일정 → 상세보기 버튼
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
                                builder: (_) =>
                                    ScheduleDetailScreen(schedule: _selected!),
                              ),
                            );
                          },
                        ),
                      ),

                    // 장소 수 표시 (선택 없을 때)
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
                              '장소 ${_schedules.length}곳',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ── 선택된 핀 말풍선 ──
class _SelectedMarker extends StatelessWidget {
  final Schedule schedule;
  final Color color;

  const _SelectedMarker({required this.schedule, required this.color});

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
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
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
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        Icon(Icons.location_on, color: color, size: 24),
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
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
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
