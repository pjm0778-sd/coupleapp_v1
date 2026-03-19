import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme.dart';
import '../models/midpoint_input.dart';
import '../models/midpoint_result.dart';
import '../services/midpoint_service.dart';
import '../widgets/date_spots_widget.dart';
import '../widgets/midpoint_city_card.dart';
import '../widgets/midpoint_map_widget.dart';
import '../widgets/route_comparison_table.dart';
import '../widgets/route_steps_widget.dart';

class MidpointResultScreen extends StatefulWidget {
  final List<MidpointResult> results;
  final MidpointSearchInput input;

  const MidpointResultScreen({
    super.key,
    required this.results,
    required this.input,
  });

  @override
  State<MidpointResultScreen> createState() => _MidpointResultScreenState();
}

class _MidpointResultScreenState extends State<MidpointResultScreen> {
  int _selectedIndex = 0;

  final _service = MidpointService();

  // 도시 인덱스별 데이트 명소 상태
  final Map<int, List<DateSpot>> _dateSpots = {};
  final Map<int, bool> _loading = {};
  final Map<int, bool> _hasMore = {}; // true = "더 보기" 버튼 표시

  MidpointResult get _selected => widget.results[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _loadPreview(0);
  }

  Future<void> _loadPreview(int index) async {
    if (_dateSpots.containsKey(index)) return; // 이미 로딩됨
    setState(() => _loading[index] = true);

    final cityName = widget.results[index].city.name;
    final spots = await _service.fetchDateSpots(
      cityName,
      widget.input.theme,
      preview: true,
    );

    if (!mounted) return;
    setState(() {
      _dateSpots[index] = spots;
      _loading[index] = false;
      _hasMore[index] = spots.isNotEmpty;
    });
  }

  Future<void> _loadMore(int index) async {
    setState(() => _loading[index] = true);

    final cityName = widget.results[index].city.name;
    final existing = _dateSpots[index] ?? [];
    final more = await _service.fetchDateSpots(
      cityName,
      widget.input.theme,
      preview: false,
      exclude: existing.map((s) => s.name).toList(),
    );

    if (!mounted) return;
    setState(() {
      _dateSpots[index] = [...existing, ...more];
      _loading[index] = false;
      _hasMore[index] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          leading: const BackButton(color: AppTheme.textPrimary),
          title: const Text('중간지점 결과'),
        ),
        body: const Center(child: Text('결과를 찾을 수 없습니다.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
        title: const Text('추천 중간지점',
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
            // ── 도시 카드 가로 스크롤 ──
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.results.length,
                itemBuilder: (_, i) => MidpointCityCard(
                  result: widget.results[i],
                  selected: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    _loadPreview(i);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 추천 이유 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selected.city.reason,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 경로 비교표 ──
            const Text('경로 비교',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            RouteComparisonTable(
              myRoute: _selected.myRoute,
              partnerRoute: _selected.partnerRoute,
            ),

            // ── 내 경로 세부 단계 ──
            if (_selected.myRoute.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionLabel(label: '${_selected.myRoute.originName} 경로'),
              const SizedBox(height: 6),
              RouteStepsWidget(steps: _selected.myRoute.steps),
            ],

            // ── 상대방 경로 세부 단계 ──
            if (_selected.partnerRoute.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionLabel(label: '${_selected.partnerRoute.originName} 경로'),
              const SizedBox(height: 6),
              RouteStepsWidget(steps: _selected.partnerRoute.steps),
            ],

            const SizedBox(height: 20),

            // ── 지도 ──
            const Text('지도',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            _MapPlaceholder(city: _selected.city, places: _selected.nearbyPlaces),
            const SizedBox(height: 20),

            // ── 데이트 명소 (Claude 추천) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selected.city.name} 데이트 추천',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                if ((_dateSpots[_selectedIndex]?.length ?? 0) > 0)
                  Text('${_dateSpots[_selectedIndex]!.length}곳',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            DateSpotsWidget(
              spots: _dateSpots[_selectedIndex] ?? [],
              cityName: _selected.city.name,
              isLoading: _loading[_selectedIndex] == true,
              hasMore: _hasMore[_selectedIndex] == true,
              onLoadMore: () => _loadMore(_selectedIndex),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleSnackbar(BuildContext context) {
    // TODO Phase D: 캘린더 ScheduleAddSheet 연동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정 추가 기능은 곧 연동됩니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary));
  }
}

/// 출발지 좌표 없이 중간지점만 표시하는 지도 (MVP)
class _MapPlaceholder extends StatelessWidget {
  final MidpointCity city;
  final List<NearbyPlace> places;

  const _MapPlaceholder({required this.city, required this.places});

  @override
  Widget build(BuildContext context) {
    // 지도에 출발지 핀을 표시하려면 MidpointService.search()에서
    // geocode된 출발지 좌표를 MidpointResult에 포함시켜야 함
    // MVP: 중간지점 + 주변 장소 핀만 표시 (출발지 핀 생략)
    return MidpointMapWidget(
      city: city,
      myOrigin: LatLng(city.lat, city.lng), // 임시: 중간지점으로 대체
      partnerOrigin: LatLng(city.lat, city.lng),
      places: places,
    );
  }
}
