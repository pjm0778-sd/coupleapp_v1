import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_keys.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';

class TransportService {
  static const _trainBaseUrl =
      'https://apis.data.go.kr/1613000/TrainInfoService/getStrtpntAlocFndTrainInfo';
  static const _busBaseUrl =
      'https://apis.data.go.kr/1613000/ExpBusInfoService/getExpBusTrminlSchdl';

  /// 출발역/터미널 → 도착역/터미널 교통편 통합 검색
  Future<TransportSearchResult> search({
    required String fromStation,
    required String toStation,
    required DateTime date,
  }) async {
    if (!ApiKeys.isConfigured) {
      return TransportSearchResult.apiKeyNotSet();
    }

    final results = <TransitResult>[];
    String? trainError;
    String? busError;
    bool hasSrtStation = false;

    // KORAIL 열차 조회
    final depKorail = korailStationCodes[fromStation];
    final arrKorail = korailStationCodes[toStation];

    if (depKorail == 'SRT_ONLY' || arrKorail == 'SRT_ONLY') {
      hasSrtStation = true;
    }

    if (depKorail != null &&
        arrKorail != null &&
        depKorail != 'SRT_ONLY' &&
        depKorail != 'AIRPORT' &&
        arrKorail != 'SRT_ONLY' &&
        arrKorail != 'AIRPORT') {
      try {
        final trains = await _fetchTrains(
          depCode: depKorail,
          arrCode: arrKorail,
          date: date,
        );
        results.addAll(trains);
      } catch (e) {
        trainError = e.toString();
        debugPrint('KORAIL API error: $e');
      }
    }

    // 고속버스 조회
    final depBus = busTerminalCodes[fromStation];
    final arrBus = busTerminalCodes[toStation];

    if (depBus != null && arrBus != null) {
      try {
        final buses = await _fetchBuses(
          depCode: depBus,
          arrCode: arrBus,
          date: date,
        );
        results.addAll(buses);
      } catch (e) {
        busError = e.toString();
        debugPrint('Bus API error: $e');
      }
    }

    // 출발시간 순 정렬
    results.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return TransportSearchResult(
      results: results,
      hasSrtStation: hasSrtStation,
      trainError: trainError,
      busError: busError,
    );
  }

  Future<List<TransitResult>> _fetchTrains({
    required String depCode,
    required String arrCode,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(_trainBaseUrl).replace(queryParameters: {
      'serviceKey': ApiKeys.dataGoKr,
      'numOfRows': '30',
      'pageNo': '1',
      '_type': 'json',
      'depPlaceId': depCode,
      'arrPlaceId': arrCode,
      'depPlandTime': dateStr,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final resBody = body['response']?['body'] as Map<String, dynamic>?;
    if (resBody == null) throw Exception('응답 형식 오류');

    final items = _extractItems(resBody);
    return items.map(_parseTrainItem).whereType<TransitResult>().toList();
  }

  Future<List<TransitResult>> _fetchBuses({
    required String depCode,
    required String arrCode,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(_busBaseUrl).replace(queryParameters: {
      'serviceKey': ApiKeys.dataGoKr,
      'numOfRows': '30',
      'pageNo': '1',
      '_type': 'json',
      'depTerminalId': depCode,
      'arrTerminalId': arrCode,
      'depPlandTime': dateStr,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final resBody = body['response']?['body'] as Map<String, dynamic>?;
    if (resBody == null) throw Exception('응답 형식 오류');

    final items = _extractItems(resBody);
    return items.map(_parseBusItem).whereType<TransitResult>().toList();
  }

  /// 한국 공공 API의 XML→JSON 변환 특성:
  /// 결과가 1건이면 item이 Map, 여러 건이면 List
  List<dynamic> _extractItems(Map<String, dynamic> body) {
    final items = body['items'];
    if (items == null || items is String) return [];
    final item = (items as Map<String, dynamic>)['item'];
    if (item == null) return [];
    if (item is List) return item;
    return [item];
  }

  TransitResult? _parseTrainItem(dynamic raw) {
    try {
      final map = raw as Map<String, dynamic>;
      final gradeName = (map['traingradename'] as String? ?? '').toLowerCase();
      final type = _trainGradeToType(gradeName);
      final depTime = _parseTrainTime(map['depplandtime']);
      final arrTime = _parseTrainTime(map['arrplandtime']);
      final duration = _calcDuration(map['depplandtime'], map['arrplandtime']);
      final priceRaw = map['adultcharge'];
      final price = priceRaw != null ? int.tryParse(priceRaw.toString()) : null;

      return TransitResult(
        type: type,
        trainNo: map['trainno']?.toString() ?? '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: duration,
        price: price,
      );
    } catch (e) {
      debugPrint('Train item parse error: $e / $raw');
      return null;
    }
  }

  TransitResult? _parseBusItem(dynamic raw) {
    try {
      final map = raw as Map<String, dynamic>;
      final gradeName = (map['busGradeName'] as String? ?? '').trim();
      final type = gradeName.contains('우등') || gradeName.contains('프리미엄')
          ? TransitType.expressbus
          : TransitType.bus;
      final depTime = _parseBusTime(map['depPlandTime']);
      final arrTime = _parseBusTime(map['arrPlandTime']);
      final priceRaw = map['charge'];
      final price = priceRaw != null ? int.tryParse(priceRaw.toString()) : null;

      // 버스는 소요시간이 없을 수 있어 출발/도착 차이로 계산
      final duration = _calcBusDuration(depTime, arrTime);

      return TransitResult(
        type: type,
        trainNo: map['routeId']?.toString() ?? '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: duration,
        price: price,
      );
    } catch (e) {
      debugPrint('Bus item parse error: $e / $raw');
      return null;
    }
  }

  TransitType _trainGradeToType(String grade) {
    if (grade.startsWith('ktx')) return TransitType.ktx;
    if (grade.startsWith('srt')) return TransitType.srt;
    if (grade.startsWith('itx') || grade.contains('새마을') || grade.contains('청춘')) {
      return TransitType.itx;
    }
    return TransitType.mugunghwa;
  }

  /// KORAIL API 시각: 20260318080000 (YYYYMMDDHHmmss as num)
  String _parseTrainTime(dynamic val) {
    final s = val?.toString() ?? '';
    if (s.length < 12) return '--:--';
    return '${s.substring(8, 10)}:${s.substring(10, 12)}';
  }

  int _calcDuration(dynamic dep, dynamic arr) {
    final ds = dep?.toString() ?? '';
    final as_ = arr?.toString() ?? '';
    if (ds.length < 12 || as_.length < 12) return 0;
    final dh = int.parse(ds.substring(8, 10));
    final dm = int.parse(ds.substring(10, 12));
    final ah = int.parse(as_.substring(8, 10));
    final am = int.parse(as_.substring(10, 12));
    var depMin = dh * 60 + dm;
    var arrMin = ah * 60 + am;
    if (arrMin < depMin) arrMin += 24 * 60; // 자정 넘기는 경우
    return arrMin - depMin;
  }

  /// 버스 API 시각: "0800" (HHmm string)
  String _parseBusTime(dynamic val) {
    final s = (val?.toString() ?? '').padLeft(4, '0');
    if (s.length < 4) return '--:--';
    return '${s.substring(0, 2)}:${s.substring(2, 4)}';
  }

  int _calcBusDuration(String dep, String arr) {
    if (dep == '--:--' || arr == '--:--') return 0;
    try {
      final dh = int.parse(dep.substring(0, 2));
      final dm = int.parse(dep.substring(3, 5));
      final ah = int.parse(arr.substring(0, 2));
      final am = int.parse(arr.substring(3, 5));
      var depMin = dh * 60 + dm;
      var arrMin = ah * 60 + am;
      if (arrMin < depMin) arrMin += 24 * 60;
      return arrMin - depMin;
    } catch (_) {
      return 0;
    }
  }
}

class TransportSearchResult {
  final List<TransitResult> results;
  final bool hasSrtStation;
  final bool apiKeyNotConfigured;
  final String? trainError;
  final String? busError;

  const TransportSearchResult({
    required this.results,
    this.hasSrtStation = false,
    this.apiKeyNotConfigured = false,
    this.trainError,
    this.busError,
  });

  factory TransportSearchResult.apiKeyNotSet() => const TransportSearchResult(
        results: [],
        apiKeyNotConfigured: true,
      );

  List<TransitResult> get trainResults =>
      results.where((r) => r.isRailway).toList();

  List<TransitResult> get busResults =>
      results.where((r) => !r.isRailway).toList();

  bool get hasError => trainError != null || busError != null;

  bool get isEmpty => results.isEmpty;
}
