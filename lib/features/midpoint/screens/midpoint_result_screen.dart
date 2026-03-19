import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme.dart';
import '../models/midpoint_input.dart';
import '../models/midpoint_result.dart';
import '../widgets/midpoint_city_card.dart';
import '../widgets/midpoint_map_widget.dart';
import '../widgets/nearby_places_list.dart';
import '../widgets/route_comparison_table.dart';

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

  MidpointResult get _selected => widget.results[_selectedIndex];

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
                  onTap: () => setState(() => _selectedIndex = i),
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
            const SizedBox(height: 20),

            // ── 지도 ──
            const Text('지도',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            // 지도는 출발지 좌표가 필요하므로 서비스에서 받아야 하나
            // MVP에서는 중간지점 + 장소 핀만 표시
            _MapPlaceholder(city: _selected.city, places: _selected.nearbyPlaces),
            const SizedBox(height: 20),

            // ── 주변 장소 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('주변 장소',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('${_selected.nearbyPlaces.length}곳',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            NearbyPlacesList(
              places: _selected.nearbyPlaces,
              midpointCityName: _selected.city.name,
              onAddSchedule: () => _showAddScheduleSnackbar(context),
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
