enum TransitType { ktx, srt, itx, mugunghwa, expressbus, bus }

class TransitResult {
  final TransitType type;
  final String trainNo;
  final String departureTime; // "08:00"
  final String arrivalTime; // "10:30"
  final int durationMinutes;
  const TransitResult({
    required this.type,
    required this.trainNo,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
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
        return '우등';
      case TransitType.bus:
        return '일반';
    }
  }

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  bool get isRailway =>
      type == TransitType.ktx ||
      type == TransitType.srt ||
      type == TransitType.itx ||
      type == TransitType.mugunghwa;
}
