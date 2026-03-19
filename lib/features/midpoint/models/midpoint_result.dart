import 'midpoint_input.dart';

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

class RouteInfo {
  final String originName;
  final TransportMode mode;
  final String transitLabel;     // "지하철", "KTX", "고속버스", "일반차", "전기차"
  final double distanceKm;
  final int durationMinutes;
  final int estimatedCost;       // 원
  final bool isEstimated;        // true = Claude 추정값 폴백
  final String? estimatedNote;

  const RouteInfo({
    required this.originName,
    required this.mode,
    required this.transitLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedCost,
    this.isEstimated = false,
    this.estimatedNote,
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

  /// 카테고리 전체명에서 마지막 분류만 추출 (예: "음식점 > 한식" → "한식")
  String get shortCategory {
    final parts = category.split('>');
    return parts.last.trim();
  }
}

class MidpointResult {
  final MidpointCity city;
  final RouteInfo myRoute;
  final RouteInfo partnerRoute;
  final List<NearbyPlace> nearbyPlaces;

  const MidpointResult({
    required this.city,
    required this.myRoute,
    required this.partnerRoute,
    required this.nearbyPlaces,
  });
}
