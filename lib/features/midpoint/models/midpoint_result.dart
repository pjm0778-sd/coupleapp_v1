import 'midpoint_input.dart';

// ── 경로 세부 단계 ──────────────────────────────
enum RouteStepType { walk, subway, bus, train }

class RouteStep {
  final RouteStepType type;
  final String? lineName;      // "1호선", "SRT", "경기고속"
  final String? startStation;  // 출발역/정류장
  final String? endStation;    // 도착역/정류장
  final int durationMinutes;

  const RouteStep({
    required this.type,
    this.lineName,
    this.startStation,
    this.endStation,
    required this.durationMinutes,
  });

  String get icon {
    switch (type) {
      case RouteStepType.walk:   return '🚶';
      case RouteStepType.subway: return '🚇';
      case RouteStepType.bus:    return '🚌';
      case RouteStepType.train:  return '🚄';
    }
  }

  String get label {
    switch (type) {
      case RouteStepType.walk:   return '도보';
      case RouteStepType.subway: return lineName ?? '지하철';
      case RouteStepType.bus:    return lineName ?? '버스';
      case RouteStepType.train:  return lineName ?? '열차';
    }
  }

  String get durationLabel {
    if (durationMinutes < 1) return '';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}

// ── 데이트 명소 ──────────────────────────────────
class DateSpot {
  final String name;
  final String category;
  final String description;
  final String tip;

  const DateSpot({
    required this.name,
    required this.category,
    required this.description,
    required this.tip,
  });

  String get categoryIcon {
    if (category.contains('카페'))   return '☕';
    if (category.contains('음식점')) return '🍽';
    if (category.contains('명소'))   return '🏛';
    if (category.contains('체험'))   return '🎯';
    if (category.contains('쇼핑'))   return '🛍';
    return '📍';
  }
}

// ── 도시 ─────────────────────────────────────────
class MidpointCity {
  final String name;
  final String reason;
  final double lat;
  final double lng;
  final int estimatedMinutesA;
  final int estimatedMinutesB;

  const MidpointCity({
    required this.name,
    required this.reason,
    required this.lat,
    required this.lng,
    required this.estimatedMinutesA,
    required this.estimatedMinutesB,
  });
}

// ── 경로 정보 ─────────────────────────────────────
class RouteInfo {
  final String originName;
  final TransportMode mode;
  final String transitLabel;
  final double distanceKm;
  final int durationMinutes;
  final int estimatedCost;
  final bool isEstimated;
  final String? estimatedNote;
  final List<RouteStep> steps;

  const RouteInfo({
    required this.originName,
    required this.mode,
    required this.transitLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedCost,
    this.isEstimated = false,
    this.estimatedNote,
    this.steps = const [],
  });

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  String get costLabel {
    if (estimatedCost == 0) return '요금 미확인';
    final formatted = estimatedCost.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '약 $formatted원';
  }
}

// ── 주변 장소 (Kakao) ─────────────────────────────
class NearbyPlace {
  final String name;
  final String category;
  final double lat;
  final double lng;
  final String? address;
  final String? kakaoUrl;

  const NearbyPlace({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.address,
    this.kakaoUrl,
  });

  String get shortCategory {
    final parts = category.split('>');
    return parts.last.trim();
  }
}

// ── 중간지점 추천 유형 ────────────────────────────
enum MidpointType {
  geographic, // 지리적 중간
  fastest,    // 최단 시간
  dateSpot,   // 데이트 추천
}

extension MidpointTypeLabel on MidpointType {
  String get label {
    switch (this) {
      case MidpointType.geographic: return '지리적 중간';
      case MidpointType.fastest:    return '최단 시간';
      case MidpointType.dateSpot:   return '데이트 추천';
    }
  }

  String get icon {
    switch (this) {
      case MidpointType.geographic: return '📍';
      case MidpointType.fastest:    return '⚡';
      case MidpointType.dateSpot:   return '💑';
    }
  }
}

// ── 최종 결과 ─────────────────────────────────────
class MidpointResult {
  final MidpointCity city;
  final RouteInfo myRoute;
  final RouteInfo partnerRoute;
  final List<NearbyPlace> nearbyPlaces;
  final List<DateSpot> dateSpots;
  final MidpointType type;

  const MidpointResult({
    required this.city,
    required this.myRoute,
    required this.partnerRoute,
    required this.nearbyPlaces,
    this.dateSpots = const [],
    this.type = MidpointType.geographic,
  });
}
