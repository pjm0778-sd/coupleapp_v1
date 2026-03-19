import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart' show supabaseUrl, supabaseAnonKey;
import '../../transport/services/transport_service.dart';
import '../models/midpoint_input.dart';
import '../models/midpoint_result.dart';
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
    // 1. 좌표가 없을 때만 geocoding (Kakao fallback)
    final resolvedMyLatLng = myLatLng ?? await _geocode(input.myOrigin);
    final resolvedPartnerLatLng = partnerLatLng ?? await _geocode(input.partnerOrigin);

    if (resolvedMyLatLng == null || resolvedPartnerLatLng == null) {
      throw Exception('출발지 좌표를 찾을 수 없습니다. 주소를 다시 확인해주세요.');
    }

    // 변수 재할당 (이후 코드 호환)
    final myLatLngResolved = resolvedMyLatLng;
    final partnerLatLngResolved = resolvedPartnerLatLng;

    // 2. Claude로 중간지점 도시 추론
    final cities = await _inferMidpoints(input);
    if (cities.isEmpty) throw Exception('중간지점을 찾을 수 없습니다.');

    // 3. 각 도시별 상세 정보 병렬 조회
    final results = await Future.wait(
      cities.map((city) => _buildResult(
            city: city,
            input: input,
            myLatLng: myLatLngResolved,
            partnerLatLng: partnerLatLngResolved,
          )),
    );

    return results.whereType<MidpointResult>().toList();
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
  // Claude API로 중간지점 도시 추론
  // ────────────────────────────────────────────────
  Future<List<MidpointCity>> _inferMidpoints(MidpointSearchInput input) async {
    try {
      final uri = Uri.parse(_claudeBase);
      final res = await http.post(
        uri,
        headers: {
          ..._authHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(input.toJson()),
      );

      if (res.statusCode != 200) {
        debugPrint('[MidpointService] Claude error ${res.statusCode}: ${res.body}');
        return [];
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final citiesJson = data['cities'] as List? ?? [];

      // 도시 좌표는 이름으로 별도 geocode
      final cities = await Future.wait(citiesJson.map((c) async {
        final name = c['name'] as String;
        final latLng = await _geocode(name);
        if (latLng == null) return null;
        return MidpointCity(
          name: name,
          reason: c['reason'] as String,
          lat: latLng.latitude,
          lng: latLng.longitude,
          estimatedMinutesA: c['estimatedMinutesA'] as int,
          estimatedMinutesB: c['estimatedMinutesB'] as int,
        );
      }));

      return cities.whereType<MidpointCity>().toList();
    } catch (e) {
      debugPrint('[MidpointService] Claude error: $e');
      return [];
    }
  }

  // ────────────────────────────────────────────────
  // 도시 1곳에 대한 전체 결과 구성
  // ────────────────────────────────────────────────
  Future<MidpointResult?> _buildResult({
    required MidpointCity city,
    required MidpointSearchInput input,
    required LatLng myLatLng,
    required LatLng partnerLatLng,
  }) async {
    final midLatLng = LatLng(city.lat, city.lng);

    // 경로 + 장소 병렬 조회
    final (myRoute, partnerRoute, places) = await (
      _fetchRoute(
        origin: myLatLng,
        originName: input.myOrigin,
        destination: midLatLng,
        destinationCityName: city.name,
        mode: input.myMode,
        carType: input.myCarType,
        claudeEstimateMinutes: city.estimatedMinutesA,
      ),
      _fetchRoute(
        origin: partnerLatLng,
        originName: input.partnerOrigin,
        destination: midLatLng,
        destinationCityName: city.name,
        mode: input.partnerMode,
        carType: input.partnerCarType,
        claudeEstimateMinutes: city.estimatedMinutesB,
      ),
      _fetchNearbyPlaces(midLatLng, input.theme),
    ).wait;

    return MidpointResult(
      city: city,
      myRoute: myRoute,
      partnerRoute: partnerRoute,
      nearbyPlaces: places,
    );
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
    required int claudeEstimateMinutes,
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
      );
    }

    // ── 2차: 열차/KTX + 3차: 고속버스 (TransportService 기존 로직 재사용) ──
    final originCity = _extractCityName(originName);
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
        );
      }

      // ── 3차: 고속버스 (searchInterBusSchedule) ──
      if (trainResults.busResults.isNotEmpty) {
        final best = trainResults.busResults.first;
        return RouteInfo(
          originName: originName,
          mode: TransportMode.publicTransit,
          transitLabel: best.typeLabel,
          distanceKm: distKm,
          durationMinutes: best.durationMinutes,
          estimatedCost: best.fare ?? 0,
        );
      }
    } catch (e) {
      debugPrint('[MidpointService] transit search error: $e');
    }

    // ── 최종 폴백: Claude 추정값 ──
    return RouteInfo(
      originName: originName,
      mode: TransportMode.publicTransit,
      transitLabel: '대중교통 (추정)',
      distanceKm: distKm,
      durationMinutes: claudeEstimateMinutes,
      estimatedCost: 0,
      isEstimated: true,
      estimatedNote: '이 지역은 정확한 대중교통 정보를 제공하기 어렵습니다. 직접 확인을 권장합니다.',
    );
  }

  // ODsay 지하철 통합경로 조회
  Future<({int durationMinutes, int fare})?> _trySubway(
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

      return (
        durationMinutes: (info['totalTime'] as num).toInt(),
        fare: (info['payment'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('[MidpointService] subway error: $e');
      return null;
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
