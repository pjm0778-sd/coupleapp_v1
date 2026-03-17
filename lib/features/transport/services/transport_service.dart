import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_keys.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';

class TransportService {

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

    // ── KORAIL 열차 조회 ──
    final depApiName = korailApiStationNames[fromStation];
    final arrApiName = korailApiStationNames[toStation];

    if (depApiName == 'SRT_ONLY' || arrApiName == 'SRT_ONLY') {
      hasSrtStation = true;
    }

    if (depApiName != null &&
        arrApiName != null &&
        depApiName != 'SRT_ONLY' &&
        arrApiName != 'SRT_ONLY') {
      try {
        final trains = await _fetchTrains(
          depName: depApiName,
          arrName: arrApiName,
          date: date,
        );
        results.addAll(trains);
      } catch (e) {
        trainError = e.toString();
        debugPrint('KORAIL API error: $e');
      }
    }

    // ── 고속버스 조회 ──
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

    results.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return TransportSearchResult(
      results: results,
      hasSrtStation: hasSrtStation,
      trainError: trainError,
      busError: busError,
    );
  }

  Future<List<TransitResult>> _fetchTrains({
    required String depName,
    required String arrName,
    required DateTime date,
  }) async {
    final ymd = _fmtDate(date);

    // cond[...] 파라미터의 대괄호/콜론이 이중 인코딩되지 않도록 query 문자열 직접 구성
    final rawQuery = 'serviceKey=${Uri.encodeComponent(ApiKeys.dataGoKr)}'
        '&numOfRows=50&pageNo=1'
        '&cond[run_ymd::GTE]=$ymd'
        '&cond[run_ymd::LTE]=$ymd'
        '&cond[dptre_stn_nm::EQ]=${Uri.encodeComponent(depName)}'
        '&cond[arvl_stn_nm::EQ]=${Uri.encodeComponent(arrName)}';

    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/B551457/run/v2/travelerTrainRunPlan2',
      query: rawQuery,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final items = _extractItems(decoded);
    return items.map(_parseTrainItem).whereType<TransitResult>().toList();
  }

  Future<List<TransitResult>> _fetchBuses({
    required String depCode,
    required String arrCode,
    required DateTime date,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/1613000/ExpBusInfoService/getExpBusTrminlSchdl',
      queryParameters: {
        'serviceKey': ApiKeys.dataGoKr,
        'numOfRows': '30',
        'pageNo': '1',
        '_type': 'json',
        'depTerminalId': depCode,
        'arrTerminalId': arrCode,
        'depPlandTime': _fmtDate(date),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final resBody = body['response']?['body'] as Map<String, dynamic>?;
    if (resBody == null) throw Exception('응답 형식 오류');

    final items = _extractItems1613(resBody);
    return items.map(_parseBusItem).whereType<TransitResult>().toList();
  }

  // ── B551457 응답 파싱 ──
  // 응답 구조 예: { "header": {...}, "body": { "items": [...] } }
  // 또는 { "response": { "body": { "items": { "item": [...] } } } }
  List<dynamic> _extractItems(dynamic decoded) {
    try {
      // B551457 API 응답 구조 시도 1: { body: { items: [...] } }
      final body = (decoded as Map<String, dynamic>)['body'];
      if (body != null) {
        final items = body['items'];
        if (items is List) return items;
        if (items is Map) {
          final item = items['item'];
          if (item is List) return item;
          if (item != null) return [item];
        }
      }
      // 시도 2: { response: { body: { items: { item: [...] } } } }
      final response = (decoded as Map)['response'];
      if (response != null) {
        return _extractItems1613(response['body'] as Map<String, dynamic>? ?? {});
      }
    } catch (e) {
      debugPrint('_extractItems error: $e');
    }
    return [];
  }

  /// 1613000 API (고속버스): items.item 이 1건이면 Map, 여러 건이면 List
  List<dynamic> _extractItems1613(Map<String, dynamic> body) {
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

      // 열차 종별: trn_grd_cd, trn_clsf_cd 등 여러 키 시도
      final grade = (map['trn_grd_cd'] ??
              map['trn_clsf_cd'] ??
              map['train_grade'] ??
              map['trnGrdCd'] ??
              '')
          .toString()
          .toLowerCase();
      final type = _trainGradeToType(grade);

      // 출발/도착 시각: trn_plan_dptre_dtime 형식 예) "20260318080000" 또는 "2026-03-18 08:00:00"
      final depRaw = map['trn_plan_dptre_dtime'] ?? map['depplandtime'] ?? map['dptreDtime'] ?? '';
      final arrRaw = map['trn_plan_arvl_dtime'] ?? map['arrplandtime'] ?? map['arvlDtime'] ?? '';

      final depTime = _parseDateTime(depRaw.toString());
      final arrTime = _parseDateTime(arrRaw.toString());
      final duration = _calcDuration(depRaw.toString(), arrRaw.toString());

      // 열차번호
      final trainNo = (map['trn_no'] ?? map['trainno'] ?? map['trnNo'] ?? '').toString();

      return TransitResult(
        type: type,
        trainNo: trainNo,
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: duration,
        price: null, // 이 API는 요금 미제공
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
    if (grade.contains('ktx')) return TransitType.ktx;
    if (grade.contains('srt')) return TransitType.srt;
    if (grade.contains('itx') ||
        grade.contains('새마을') ||
        grade.contains('청춘') ||
        grade.contains('saemaul')) {
      return TransitType.itx;
    }
    return TransitType.mugunghwa;
  }

  /// 날짜 → YYYYMMDD
  String _fmtDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// 시각 파싱: "20260318080000" 또는 "2026-03-18 08:00:00" → "08:00"
  String _parseDateTime(String raw) {
    if (raw.isEmpty) return '--:--';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 12) {
      return '${digits.substring(8, 10)}:${digits.substring(10, 12)}';
    }
    return '--:--';
  }

  int _calcDuration(String depRaw, String arrRaw) {
    final d = depRaw.replaceAll(RegExp(r'\D'), '');
    final a = arrRaw.replaceAll(RegExp(r'\D'), '');
    if (d.length < 12 || a.length < 12) return 0;
    final dh = int.parse(d.substring(8, 10));
    final dm = int.parse(d.substring(10, 12));
    final ah = int.parse(a.substring(8, 10));
    final am = int.parse(a.substring(10, 12));
    var depMin = dh * 60 + dm;
    var arrMin = ah * 60 + am;
    if (arrMin < depMin) arrMin += 24 * 60;
    return arrMin - depMin;
  }

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
