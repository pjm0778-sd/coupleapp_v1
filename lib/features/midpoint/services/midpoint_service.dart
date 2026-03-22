import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart' show supabaseUrl, supabaseAnonKey;
import '../../transport/services/transport_service.dart';
import '../data/korean_cities.dart';
import '../models/midpoint_input.dart';
import '../models/midpoint_result.dart'
    show
        DateSpot,
        MidpointCity,
        MidpointResult,
        MidpointType,
        NearbyPlace,
        RouteInfo,
        RouteStep,
        RouteStepType;
import 'naver_directions_service.dart';

class MidpointService {
  final _directions = NaverDirectionsService();
  final _transport = TransportService();

  static const String _kakaoBase = '$supabaseUrl/functions/v1/kakao-place-search';
  static const String _claudeBase = '$supabaseUrl/functions/v1/claude-midpoint';

  // ────────────────────────────────────────────────
  // 메인 진입점
  // ────────────────────────────────────────────────
  Future<List<MidpointResult>> search(
    MidpointSearchInput input, {
    LatLng? myLatLng,
    LatLng? partnerLatLng,
  }) async {
    // 1. 좌표 확인
    final myLL      = myLatLng      ?? await _geocode(input.myOrigin);
    final partnerLL = partnerLatLng ?? await _geocode(input.partnerOrigin);

    if (myLL == null || partnerLL == null) {
      throw Exception('출발지 좌표를 찾을 수 없습니다. 주소를 다시 확인해주세요.');
    }

    // 2. 후보 도시 선별 (균형 기준 상위 10개)
    final candidates = _filterCandidateCities(myLL, partnerLL);

    // 3. 후보 도시별 실제 경로 시간 병렬 조회
    final routePairs = await Future.wait(
      candidates.map((city) async {
        final cityLL = LatLng(city.lat, city.lng);
        final routes = await Future.wait([
          _fetchRoute(
            origin: myLL,
            originName: input.myOrigin,
            destination: cityLL,
            destinationCityName: city.name,
            mode: input.myMode,
            carType: input.myCarType,
          ),
          _fetchRoute(
            origin: partnerLL,
            originName: input.partnerOrigin,
            destination: cityLL,
            destinationCityName: city.name,
            mode: input.partnerMode,
            carType: input.partnerCarType,
          ),
        ]);
        return (city: city, myRoute: routes[0], partnerRoute: routes[1]);
      }),
    );

    // 4. 3가지 기준으로 각각 최적 도시 선택 (중복 제거)
    final midLL = LatLng(
      (myLL.latitude + partnerLL.latitude) / 2,
      (myLL.longitude + partnerLL.longitude) / 2,
    );
    final top3 = _pickTop3(routePairs, midLL);
    if (top3.isEmpty) throw Exception('중간지점을 찾을 수 없습니다.');

    // 5. Claude로 도시 설명 생성
    final descriptions = await _fetchDescriptions(
      top3.map((r) => r.$1.city.name).toList(),
      input.theme,
    );

    // 6. 주변 장소 + 최종 결과 조립
    final results = await Future.wait(
      top3.map((r) async {
        final pair = r.$1;
        final type = r.$2;
        final cityLL = LatLng(pair.city.lat, pair.city.lng);
        final places = await _fetchNearbyPlaces(cityLL, input.theme);

        return MidpointResult(
          city: MidpointCity(
            name: pair.city.name,
            reason: descriptions[pair.city.name] ?? '${input.theme.label}에 어울리는 도시입니다.',
            lat: pair.city.lat,
            lng: pair.city.lng,
            estimatedMinutesA: pair.myRoute.durationMinutes,
            estimatedMinutesB: pair.partnerRoute.durationMinutes,
          ),
          myRoute: pair.myRoute,
          partnerRoute: pair.partnerRoute,
          nearbyPlaces: places,
          dateSpots: [],
          type: type,
        );
      }),
    );

    return results.toList();
  }

  // ────────────────────────────────────────────────
  // 수학 필터: 균형 기준 상위 10개 후보 선별
  // ────────────────────────────────────────────────
  List<KoreanCity> _filterCandidateCities(LatLng myLL, LatLng partnerLL) {
    final scored = kKoreanCities.map((city) {
      final cityLL = LatLng(city.lat, city.lng);
      final distA  = _haversineKm(myLL, cityLL);
      final distB  = _haversineKm(partnerLL, cityLL);
      final total  = distA + distB;
      if (total == 0) return null;
      final balance = (distA - distB).abs() / total;
      return (city: city, balance: balance, total: total);
    }).whereType<({KoreanCity city, double balance, double total})>().toList();

    scored.sort((a, b) => a.balance.compareTo(b.balance));
    return scored.take(10).map((r) => r.city).toList();
  }

  // ────────────────────────────────────────────────
  // 3가지 기준으로 최적 도시 선택 (중복 제거)
  // ────────────────────────────────────────────────
  // 반환: [(routePair, MidpointType), ...]
  List<(({KoreanCity city, RouteInfo myRoute, RouteInfo partnerRoute}), MidpointType)>
      _pickTop3(
    List<({KoreanCity city, RouteInfo myRoute, RouteInfo partnerRoute})> pairs,
    LatLng geoMid,
  ) {
    final used = <String>{};
    final result = <(({KoreanCity city, RouteInfo myRoute, RouteInfo partnerRoute}), MidpointType)>[];

    // ① 지리적 중간: 지리적 중간점과 가장 가까운 도시
    final byGeo = [...pairs]..sort((a, b) {
        final dA = _haversineKm(geoMid, LatLng(a.city.lat, a.city.lng));
        final dB = _haversineKm(geoMid, LatLng(b.city.lat, b.city.lng));
        return dA.compareTo(dB);
      });
    final geo = byGeo.firstOrNull;
    if (geo != null) {
      used.add(geo.city.name);
      result.add((geo, MidpointType.geographic));
    }

    // ② 최단 시간: 합산 최소 + 경미한 불균형 패널티 (합산*0.7 + 차이*0.3)
    final byFast = [...pairs]..sort((a, b) {
        final tA = a.myRoute.durationMinutes + a.partnerRoute.durationMinutes;
        final tB = b.myRoute.durationMinutes + b.partnerRoute.durationMinutes;
        final dA = (a.myRoute.durationMinutes - a.partnerRoute.durationMinutes).abs();
        final dB = (b.myRoute.durationMinutes - b.partnerRoute.durationMinutes).abs();
        final scoreA = tA * 0.7 + dA * 0.3;
        final scoreB = tB * 0.7 + dB * 0.3;
        return scoreA.compareTo(scoreB);
      });
    final fast = byFast.firstWhere((r) => !used.contains(r.city.name),
        orElse: () => byFast.first);
    if (!used.contains(fast.city.name)) {
      used.add(fast.city.name);
      result.add((fast, MidpointType.fastest));
    }

    // ③ 데이트 추천: dateScore 높을수록 + 합산 시간 적당한 도시
    // 평균 합산 시간 대비 과도하게 멀지 않으면서 dateScore 최대
    final avgTotal = pairs.isEmpty ? 300.0
        : pairs.map((r) => r.myRoute.durationMinutes + r.partnerRoute.durationMinutes)
              .reduce((a, b) => a + b) / pairs.length;
    final byDate = [...pairs]..sort((a, b) {
        final tA = a.myRoute.durationMinutes + a.partnerRoute.durationMinutes;
        final tB = b.myRoute.durationMinutes + b.partnerRoute.durationMinutes;
        // dateScore 높을수록, 합산 시간이 평균의 1.4배 이내면 우선
        final penaltyA = tA > avgTotal * 1.4 ? (tA - avgTotal * 1.4) * 2 : 0;
        final penaltyB = tB > avgTotal * 1.4 ? (tB - avgTotal * 1.4) * 2 : 0;
        final scoreA = (5 - a.city.dateScore) * 60.0 + penaltyA;
        final scoreB = (5 - b.city.dateScore) * 60.0 + penaltyB;
        return scoreA.compareTo(scoreB);
      });
    final date = byDate.firstWhere((r) => !used.contains(r.city.name),
        orElse: () => byDate.first);
    if (!used.contains(date.city.name)) {
      result.add((date, MidpointType.dateSpot));
    }

    return result;
  }

  // ────────────────────────────────────────────────
  // Claude: 도시 설명 생성 (설명만, 시간 추정 없음)
  // ────────────────────────────────────────────────
  Future<Map<String, String>> _fetchDescriptions(
    List<String> cityNames,
    DateTheme theme,
  ) async {
    try {
      final uri = Uri.parse(_claudeBase);
      final res = await http.post(
        uri,
        headers: {
          ..._authHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'cities': cityNames, 'theme': theme.apiValue}),
      );

      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final raw  = data['descriptions'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[MidpointService] descriptions error: $e');
      return {};
    }
  }

  // ────────────────────────────────────────────────
  // Kakao 키워드 검색으로 좌표 변환
  // ────────────────────────────────────────────────
  Future<LatLng?> _geocode(String query) async {
    try {
      final uri = Uri.parse('$_kakaoBase?query=${Uri.encodeComponent(query)}');
      final res = await http.get(uri, headers: _authHeaders());

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final places = data['places'] as List?;
      if (places == null || places.isEmpty) return null;

      final first = places.first;
      return LatLng(first['lat'] as double, first['lng'] as double);
    } catch (e) {
      debugPrint('[MidpointService] geocode error ($query): $e');
      return null;
    }
  }


  // ────────────────────────────────────────────────
  // 경로 조회: 자차 or 대중교통 폴백 체인
  // ────────────────────────────────────────────────
  Future<RouteInfo> _fetchRoute({
    required LatLng origin,
    required String originName,
    required LatLng destination,
    required String destinationCityName,
    required TransportMode mode,
    CarType? carType,
    int claudeEstimateMinutes = 0,
  }) async {
    if (mode == TransportMode.car) {
      return _fetchCarRoute(
        origin: origin,
        originName: originName,
        destination: destination,
        carType: carType ?? CarType.normal,
      );
    } else {
      return _fetchTransitRoute(
        origin: origin,
        originName: originName,
        destination: destination,
        destinationCityName: destinationCityName,
        claudeEstimateMinutes: claudeEstimateMinutes,
      );
    }
  }

  Future<RouteInfo> _fetchCarRoute({
    required LatLng origin,
    required String originName,
    required LatLng destination,
    required CarType carType,
  }) async {
    final result = await _directions.getDrivingRoute(
      origin: origin,
      destination: destination,
    );

    if (result != null) {
      return RouteInfo(
        originName: originName,
        mode: TransportMode.car,
        transitLabel: carType == CarType.electric ? '전기차' : '일반차',
        distanceKm: result.distanceKm,
        durationMinutes: result.durationMinutes,
        estimatedCost: result.totalCost(carType),
      );
    }

    // Naver Directions 실패 → Haversine 거리 기반 추정
    final distKm = _haversineKm(origin, destination);
    final durationMin = (distKm / 80 * 60).round(); // 평균 80km/h 가정
    final fuelCost = carType == CarType.electric
        ? (distKm / 6 * 300).round()
        : (distKm / 12 * 1700).round();
    final toll = (distKm * 50).round();

    return RouteInfo(
      originName: originName,
      mode: TransportMode.car,
      transitLabel: carType == CarType.electric ? '전기차' : '일반차',
      distanceKm: distKm,
      durationMinutes: durationMin,
      estimatedCost: fuelCost + toll,
      isEstimated: true,
      estimatedNote: '경로 정보를 불러오지 못해 추정값을 표시합니다.',
    );
  }

  Future<RouteInfo> _fetchTransitRoute({
    required LatLng origin,
    required String originName,
    required LatLng destination,
    required String destinationCityName,
    required int claudeEstimateMinutes,
  }) async {
    final distKm = _haversineKm(origin, destination);

    final originCity = _extractCityName(originName);

    // ── 1차: 지하철 (searchPubTransPathT) — 60분 이내만 수용 ──
    final subwayResult = await _trySubway(origin, destination);
    if (subwayResult != null && subwayResult.durationMinutes <= 60) {
      return RouteInfo(
        originName: originName,
        mode: TransportMode.publicTransit,
        transitLabel: '지하철',
        distanceKm: distKm,
        durationMinutes: subwayResult.durationMinutes,
        estimatedCost: subwayResult.fare,
        steps: subwayResult.steps,
      );
    }

    // ── 2차: 열차/KTX + 3차: 고속버스 ──
    try {
      final trainResults = await _transport.search(
        fromStation: originCity,
        toStation: destinationCityName,
        date: DateTime.now(),
      );
      if (trainResults.trainResults.isNotEmpty) {
        final best = trainResults.trainResults.first;
        return RouteInfo(
          originName: originName,
          mode: TransportMode.publicTransit,
          transitLabel: best.typeLabel,
          distanceKm: distKm,
          durationMinutes: best.durationMinutes,
          estimatedCost: best.fare ?? 0,
          steps: [
            RouteStep(
              type: RouteStepType.train,
              lineName: best.typeLabel,
              startStation: originCity,
              endStation: destinationCityName,
              durationMinutes: best.durationMinutes,
            ),
          ],
        );
      }

      // ── 3차: 고속버스 ──
      if (trainResults.busResults.isNotEmpty) {
        final best = trainResults.busResults.first;
        return RouteInfo(
          originName: originName,
          mode: TransportMode.publicTransit,
          transitLabel: best.typeLabel,
          distanceKm: distKm,
          durationMinutes: best.durationMinutes,
          estimatedCost: best.fare ?? 0,
          steps: [
            RouteStep(
              type: RouteStepType.bus,
              lineName: best.typeLabel,
              startStation: originCity,
              endStation: destinationCityName,
              durationMinutes: best.durationMinutes,
            ),
          ],
        );
      }
    } catch (e) {
      debugPrint('[MidpointService] transit search error: $e');
    }

    // ── 최종 폴백: Claude 추정값 (거리 기반 최소 시간 보정) ──
    // 대중교통 평균 속도 55km/h 기준 최소 시간, 환승 여유 30분 추가
    final minByDistance = (distKm / 55 * 60 + 30).round();
    final safeDuration = claudeEstimateMinutes < minByDistance
        ? minByDistance
        : claudeEstimateMinutes;
    return RouteInfo(
      originName: originName,
      mode: TransportMode.publicTransit,
      transitLabel: '대중교통 (추정)',
      distanceKm: distKm,
      durationMinutes: safeDuration,
      estimatedCost: 0,
      isEstimated: true,
      estimatedNote: '이 지역은 정확한 대중교통 정보를 제공하기 어렵습니다. 직접 확인을 권장합니다.',
    );
  }

  // ODsay 지하철 통합경로 조회 (subPath 세부 경로 파싱)
  Future<({int durationMinutes, int fare, List<RouteStep> steps})?> _trySubway(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/functions/v1/odsay-proxy'
        '?endpoint=searchPubTransPathT'
        '&sx=${origin.longitude}&sy=${origin.latitude}'
        '&ex=${destination.longitude}&ey=${destination.latitude}',
      );
      final res = await http.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final paths = data['result']?['path'] as List?;
      if (paths == null || paths.isEmpty) return null;

      final info = paths.first['info'] as Map<String, dynamic>?;
      if (info == null) return null;

      // subPath 세부 경로 파싱
      final subPaths = paths.first['subPath'] as List? ?? [];
      final steps = <RouteStep>[];
      for (final sp in subPaths) {
        final trafficType = (sp['trafficType'] as num).toInt();
        final sectionTime = (sp['sectionTime'] as num?)?.toInt() ?? 0;
        if (sectionTime == 0) continue;

        final RouteStepType type;
        switch (trafficType) {
          case 1:  type = RouteStepType.subway; break;
          case 2:  type = RouteStepType.bus;    break;
          default: type = RouteStepType.walk;   break;
        }

        steps.add(RouteStep(
          type: type,
          lineName: sp['way'] as String?,
          startStation: sp['startName'] as String?,
          endStation: sp['endName'] as String?,
          durationMinutes: sectionTime,
        ));
      }

      return (
        durationMinutes: (info['totalTime'] as num).toInt(),
        fare: (info['payment'] as num?)?.toInt() ?? 0,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[MidpointService] subway error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────
  // Claude 데이트 명소 추천 (lazy 로딩용 public 메서드)
  // preview=true: 카페·명소·음식점 각 1개 (3개)
  // preview=false: 추가 5개 (exclude 목록 제외)
  // ────────────────────────────────────────────────
  Future<List<DateSpot>> fetchDateSpots(
    String cityName,
    DateTheme theme, {
    bool preview = true,
    List<String> exclude = const [],
  }) async {
    try {
      final modeParam = preview ? 'preview' : 'more';
      final excludeParam = exclude.isNotEmpty
          ? '&exclude=${exclude.map(Uri.encodeComponent).join(',')}'
          : '';
      final uri = Uri.parse(
        '$supabaseUrl/functions/v1/claude-date-spots'
        '?city=${Uri.encodeComponent(cityName)}&theme=${theme.apiValue}'
        '&mode=$modeParam$excludeParam',
      );
      final res = await http.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) {
        debugPrint('[MidpointService] date spots HTTP ${res.statusCode}: ${res.body}');
        return [];
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        debugPrint('[MidpointService] date spots error: ${data['error']}');
        return [];
      }
      final spots = data['spots'] as List? ?? [];
      return spots.map((s) => DateSpot(
        name: s['name'] as String,
        category: s['category'] as String? ?? '',
        description: s['description'] as String? ?? '',
        tip: s['tip'] as String? ?? '',
      )).toList();
    } catch (e) {
      debugPrint('[MidpointService] date spots error: $e');
      return [];
    }
  }

  // ────────────────────────────────────────────────
  // Kakao 카테고리 검색으로 주변 장소 조회
  // ────────────────────────────────────────────────
  Future<List<NearbyPlace>> _fetchNearbyPlaces(LatLng latLng, DateTheme theme) async {
    final places = <NearbyPlace>[];

    for (final category in theme.kakaoCategories) {
      try {
        final uri = Uri.parse(
          '$_kakaoBase?mode=category'
          '&category=$category'
          '&x=${latLng.longitude}&y=${latLng.latitude}'
          '&radius=5000',
        );
        final res = await http.get(uri, headers: _authHeaders());
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body);
        final list = data['places'] as List? ?? [];
        for (final p in list) {
          places.add(NearbyPlace(
            name: p['name'] as String,
            category: p['category'] as String? ?? '',
            lat: (p['lat'] as num).toDouble(),
            lng: (p['lng'] as num).toDouble(),
            address: p['address'] as String?,
            kakaoUrl: p['kakaoUrl'] as String?,
          ));
        }
      } catch (e) {
        debugPrint('[MidpointService] places error ($category): $e');
      }
    }

    // 중복 제거 후 최대 10곳
    final seen = <String>{};
    return places.where((p) => seen.add(p.name)).take(10).toList();
  }

  // ────────────────────────────────────────────────
  // 유틸
  // ────────────────────────────────────────────────

  /// Haversine 공식으로 두 좌표 간 거리 계산 (km)
  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) *
            cos(_deg2rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  /// 주소에서 도시명 추출 ("서울 강남구" → "서울", "부산 해운대구" → "부산")
  String _extractCityName(String address) {
    return address.split(' ').first;
  }

  Map<String, String> _authHeaders() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken
        ?? supabaseAnonKey;
    return {
      'Authorization': 'Bearer $token',
      'apikey': supabaseAnonKey,
    };
  }
}
