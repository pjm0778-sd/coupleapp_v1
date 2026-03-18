enum TransitType { ktx, srt, itx, mugunghwa, expressbus, bus, intercitybus }

class TransitResult {
  final TransitType type;
  final String trainNo;
  final String departureTime; // "08:00"
  final String arrivalTime;   // "10:30"
  final int durationMinutes;
  final int? fare;             // 요금 (원), ODsay 제공 시

  const TransitResult({
    required this.type,
    required this.trainNo,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    this.fare,
  });

  String get typeLabel {
    switch (type) {
      case TransitType.ktx:
        return 'KTX';
      case TransitType.srt:
        return 'SRT';
      case TransitType.itx:
        return 'ITX';
      case TransitType.mugunghwa:
        return '무궁화';
      case TransitType.expressbus:
        return '우등고속';
      case TransitType.bus:
        return '일반고속';
      case TransitType.intercitybus:
        return '시외버스';
    }
  }

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  String get fareLabel {
    if (fare == null || fare == 0) return '';
    final formatted = fare.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  bool get isRailway =>
      type == TransitType.ktx ||
      type == TransitType.srt ||
      type == TransitType.itx ||
      type == TransitType.mugunghwa;

  bool get isIntercityBus => type == TransitType.intercitybus;
}
