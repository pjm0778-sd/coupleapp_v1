import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_keys.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';

/// 열차 역 코드 (GetCtyAcctoTrainSttnList 응답)
class _StationNode {
  final String nodeId;
  final String nodeName;
  const _StationNode(this.nodeId, this.nodeName);
}

/// 버스 터미널 코드 (GetExpBusTrminlList 응답)
class _BusTerminal {
  final String terminalId;
  final String terminalNm;
  const _BusTerminal(this.terminalId, this.terminalNm);
}

class TransportService {
  /// 시도 코드별 열차 역 목록 캐시
  final Map<String, List<_StationNode>> _stationCache = {};

  /// 역 표시명 → nodeId 캐시
  final Map<String, String?> _nodeIdCache = {};

  /// 터미널 검색어 → 터미널 목록 캐시
  final Map<String, List<_BusTerminal>> _busTerminalCache = {};

  /// 터미널 표시명 → terminalId 캐시
  final Map<String, String?> _busTerminalIdCache = {};

  /// 출발역/터미널 → 도착역/터미널 교통편 통합 검색
  Future<TransportSearchResult> search({
    required String fromStation,
    required String toStation,
    required DateTime date,
  }) async {
    final results = <TransitResult>[];
    String? trainError;
    String? busError;
    bool hasSrtStation = false;

    // ── SRT Supabase 시간표 조회 (항상 시도) ──
    try {
      final srtResults = await _fetchSrtFromSupabase(
        fromStation: fromStation,
        toStation: toStation,
        date: date,
      );
      results.addAll(srtResults);
      if (srtResults.isNotEmpty) hasSrtStation = true;
    } catch (e) {
      debugPrint('SRT Supabase error: $e');
    }

    // ── SRT 전용 역이 포함된 경우 예매 배너 표시 ──
    if (srtOnlyStations.contains(fromStation) ||
        srtOnlyStations.contains(toStation)) {
      hasSrtStation = true;
    }

    // ── TAGO 열차 조회 ──
    final isBusOnlyDep = isBusOnly(fromStation);
    final isBusOnlyArr = isBusOnly(toStation);
    final isSrtOnly = srtOnlyStations.contains(fromStation) ||
        srtOnlyStations.contains(toStation);

    // 양쪽 모두 버스 전용이 아니고, SRT 전용도 아닐 때 열차 검색
    if (!isBusOnlyDep && !isBusOnlyArr && !isSrtOnly) {
      if (!ApiKeys.isTagoConfigured) {
        trainError = 'TAGO API 키가 설정되지 않았습니다';
      } else {
        try {
          final depNodeId = await _getNodeId(fromStation);
          final arrNodeId = await _getNodeId(toStation);

          if (depNodeId != null && arrNodeId != null) {
            final trains = await _fetchTrains(
              depNodeId: depNodeId,
              arrNodeId: arrNodeId,
              date: date,
            );
            results.addAll(trains);
          } else {
            trainError =
                '역 코드를 찾을 수 없습니다 (${depNodeId == null ? fromStation : toStation})';
          }
        } catch (e) {
          trainError = e.toString();
          debugPrint('TAGO TrainInfo API error: $e');
        }
      }
    }

    // ── 고속버스 조회 ──
    // 양쪽 모두 버스 전용일 때만 버스 검색 (열차역↔버스터미널 혼합은 불가)
    if (isBusOnlyDep && isBusOnlyArr) {
      if (!ApiKeys.isTagoConfigured) {
        busError = '버스 API 키가 설정되지 않았습니다';
      } else {
        try {
          final depTermId = await _getBusTerminalId(fromStation);
          final arrTermId = await _getBusTerminalId(toStation);

          if (depTermId != null && arrTermId != null) {
            final buses = await _fetchBuses(
              depTerminalId: depTermId,
              arrTerminalId: arrTermId,
              date: date,
            );
            results.addAll(buses);
          } else {
            busError =
                '터미널 코드를 찾을 수 없습니다 (${depTermId == null ? fromStation : toStation})';
          }
        } catch (e) {
          busError = e.toString();
          debugPrint('Bus API error: $e');
        }
      }
    } else if (isBusOnlyDep != isBusOnlyArr && !isSrtOnly) {
      // 한쪽만 버스 전용 → 둘 다 버스 터미널로 시도
      if (!ApiKeys.isTagoConfigured) {
        busError = '버스 API 키가 설정되지 않았습니다';
      } else {
        try {
          final depTermId = await _getBusTerminalId(fromStation);
          final arrTermId = await _getBusTerminalId(toStation);
          if (depTermId != null && arrTermId != null) {
            final buses = await _fetchBuses(
              depTerminalId: depTermId,
              arrTerminalId: arrTermId,
              date: date,
            );
            results.addAll(buses);
          }
        } catch (_) {}
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

  // ────────────────────────────────────────────────
  // 열차 역 코드 조회
  // ────────────────────────────────────────────────

  /// 역 표시명 → TAGO nodeId 조회 (캐시 활용)
  Future<String?> _getNodeId(String stationName) async {
    if (_nodeIdCache.containsKey(stationName)) {
      return _nodeIdCache[stationName];
    }

    final apiName = stationApiNameExceptions[stationName] ??
        _deriveApiName(stationName);

    // 1순위: stationNameToProvinceCode 직접 매핑
    // 2순위: cityProvinceCodes prefix 매핑
    final cityCode = stationNameToProvinceCode[apiName] ??
        _inferProvinceCode(apiName);

    if (cityCode == null) {
      debugPrint('cityCode not found for apiName: $apiName (from $stationName)');
      _nodeIdCache[stationName] = null;
      return null;
    }

    final stations = await _getProvinceStations(cityCode);
    // 정확히 일치하는 역 우선, 없으면 포함 매칭
    final exact = stations.where((s) => s.nodeName == apiName).firstOrNull;
    final match = exact ??
        stations.where((s) => s.nodeName.contains(apiName) || apiName.contains(s.nodeName)).firstOrNull;
    _nodeIdCache[stationName] = match?.nodeId;
    if (match == null) {
      debugPrint('station not found: $apiName in cityCode=$cityCode (${stations.map((s) => s.nodeName).take(10).toList()})');
    }
    return match?.nodeId;
  }

  String _deriveApiName(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (name.endsWith('역')) name = name.substring(0, name.length - 1);
    return name;
  }

  /// apiName → 시도 코드 추론 (stationNameToProvinceCode에 없을 때)
  String? _inferProvinceCode(String apiName) {
    for (final city in cityProvinceCodes.keys) {
      if (apiName.startsWith(city)) return cityProvinceCodes[city];
    }
    if (apiName.length >= 2) {
      final prefix = apiName.substring(0, 2);
      if (cityProvinceCodes.containsKey(prefix)) return cityProvinceCodes[prefix];
    }
    return null;
  }

  Future<List<_StationNode>> _getProvinceStations(String cityCode) async {
    if (_stationCache.containsKey(cityCode)) {
      return _stationCache[cityCode]!;
    }

    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/1613000/TrainInfo/GetCtyAcctoTrainSttnList',
      queryParameters: {
        'serviceKey': ApiKeys.tagoKey,
        '_type': 'json',
        'cityCode': cityCode,
        'numOfRows': '100',
        'pageNo': '1',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('역 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _extractItems(
      body['response']?['body'] as Map<String, dynamic>? ?? {},
    );

    final stations = items
        .map((e) {
          final m = e as Map<String, dynamic>;
          final id = m['nodeid']?.toString() ?? '';
          final name = m['nodename']?.toString() ?? '';
          if (id.isEmpty || name.isEmpty) return null;
          return _StationNode(id, name);
        })
        .whereType<_StationNode>()
        .toList();

    _stationCache[cityCode] = stations;
    return stations;
  }

  // ────────────────────────────────────────────────
  // 버스 터미널 코드 조회
  // ────────────────────────────────────────────────

  /// 터미널 표시명 → TAGO terminalId 조회 (캐시 활용)
  Future<String?> _getBusTerminalId(String stationName) async {
    if (_busTerminalIdCache.containsKey(stationName)) {
      return _busTerminalIdCache[stationName];
    }

    final searchTerm = busTerminalSearchExceptions[stationName] ??
        _deriveBusSearchTerm(stationName);

    final terminals = await _searchBusTerminals(searchTerm);
    final match = terminals.firstOrNull;
    _busTerminalIdCache[stationName] = match?.terminalId;
    return match?.terminalId;
  }

  /// 터미널 표시명 → API 검색어 자동 변환
  /// 예) '동서울터미널' → '동서울', '춘천고속버스터미널' → '춘천'
  String _deriveBusSearchTerm(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    for (final suffix in [
      '종합버스터미널', '고속버스터미널', '시외버스터미널', '종합터미널', '버스터미널', '터미널'
    ]) {
      if (name.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length).trim();
        break;
      }
    }
    return name;
  }

  /// GetExpBusTrminlList: 터미널명 검색
  Future<List<_BusTerminal>> _searchBusTerminals(String searchTerm) async {
    if (_busTerminalCache.containsKey(searchTerm)) {
      return _busTerminalCache[searchTerm]!;
    }

    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/1613000/ExpBusInfo/GetExpBusTrminlList',
      queryParameters: {
        'serviceKey': ApiKeys.tagoKey,
        '_type': 'json',
        'terminalNm': searchTerm,
        'numOfRows': '10',
        'pageNo': '1',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('터미널 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _extractItems(
      body['response']?['body'] as Map<String, dynamic>? ?? {},
    );

    final terminals = items
        .map((e) {
          final m = e as Map<String, dynamic>;
          final id = m['terminalid']?.toString() ?? '';
          final nm = m['terminalNm']?.toString() ?? '';
          if (id.isEmpty || nm.isEmpty) return null;
          return _BusTerminal(id, nm);
        })
        .whereType<_BusTerminal>()
        .toList();

    _busTerminalCache[searchTerm] = terminals;
    return terminals;
  }

  // ────────────────────────────────────────────────
  // SRT Supabase 시간표 조회
  // ────────────────────────────────────────────────

  /// Supabase srt_timetable 에서 출발→도착 직행 목록 조회
  Future<List<TransitResult>> _fetchSrtFromSupabase({
    required String fromStation,
    required String toStation,
    required DateTime date,
  }) async {
    final depName = _stripStationSuffix(fromStation);
    final arrName = _stripStationSuffix(toStation);

    final rows = await Supabase.instance.client
        .from('srt_timetable')
        .select()
        .eq('dep_station', depName)
        .eq('arr_station', arrName)
        .order('dep_time');

    // 운행일 필터: 금토일 = 금(5) 토(6) 일(7) in Dart weekday
    final weekday = date.weekday;
    final isWeekend = weekday >= 5; // 5=금, 6=토, 7=일

    return (rows as List)
        .where((r) {
          final runDays = r['run_days'] as String? ?? '매일';
          if (runDays == '매일') return true;
          if (runDays == '금토일') return isWeekend;
          return true;
        })
        .map((r) {
          final depTime = r['dep_time'] as String? ?? '--:--';
          final arrTime = r['arr_time'] as String? ?? '--:--';
          return TransitResult(
            type: TransitType.srt,
            trainNo: r['train_no'] as String? ?? '',
            departureTime: depTime,
            arrivalTime: arrTime,
            durationMinutes: _calcDurationFromTimeStr(depTime, arrTime),
          );
        })
        .toList();
  }

  /// "HH:MM" 두 문자열로 소요시간(분) 계산
  int _calcDurationFromTimeStr(String dep, String arr) {
    if (dep.length < 5 || arr.length < 5) return 0;
    final dh = int.tryParse(dep.substring(0, 2)) ?? 0;
    final dm = int.tryParse(dep.substring(3, 5)) ?? 0;
    final ah = int.tryParse(arr.substring(0, 2)) ?? 0;
    final am = int.tryParse(arr.substring(3, 5)) ?? 0;
    var depMin = dh * 60 + dm;
    var arrMin = ah * 60 + am;
    if (arrMin < depMin) arrMin += 24 * 60;
    return arrMin - depMin;
  }

  /// 역 표시명에서 DB 저장명 추출
  /// "수서역 (SRT)" → "수서", "동대구역 (KTX)" → "동대구"
  String _stripStationSuffix(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (name.endsWith('역')) name = name.substring(0, name.length - 1);
    return name;
  }

  // ────────────────────────────────────────────────
  // API 호출
  // ────────────────────────────────────────────────

  /// TAGO 열차 시간표 조회 (GetStrtpntAlocFndTrainInfo)
  Future<List<TransitResult>> _fetchTrains({
    required String depNodeId,
    required String arrNodeId,
    required DateTime date,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/1613000/TrainInfo/GetStrtpntAlocFndTrainInfo',
      queryParameters: {
        'serviceKey': ApiKeys.tagoKey,
        '_type': 'json',
        'depPlaceId': depNodeId,
        'arrPlaceId': arrNodeId,
        'depPlandTime': _fmtDate(date),
        'numOfRows': '50',
        'pageNo': '1',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('열차 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _extractItems(
      body['response']?['body'] as Map<String, dynamic>? ?? {},
    );

    return items.map(_parseTrainItem).whereType<TransitResult>().toList();
  }

  /// TAGO 고속버스 시간표 조회 (GetStrtpntAlocFndExpbusInfo)
  Future<List<TransitResult>> _fetchBuses({
    required String depTerminalId,
    required String arrTerminalId,
    required DateTime date,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: 'apis.data.go.kr',
      path: '/1613000/ExpBusInfo/GetStrtpntAlocFndExpbusInfo',
      queryParameters: {
        'serviceKey': ApiKeys.tagoKey,
        '_type': 'json',
        'depTerminalId': depTerminalId,
        'arrTerminalId': arrTerminalId,
        'depPlandTime': _fmtDate(date),
        'numOfRows': '50',
        'pageNo': '1',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('버스 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _extractItems(
      body['response']?['body'] as Map<String, dynamic>? ?? {},
    );

    return items.map(_parseBusItem).whereType<TransitResult>().toList();
  }

  // ────────────────────────────────────────────────
  // 응답 파싱
  // ────────────────────────────────────────────────

  /// TAGO 공통 items 추출: item 이 1건=Map, 여러 건=List
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

      final grade = (map['traingradename'] ?? '').toString().toUpperCase();
      final type = _trainGradeToType(grade);

      final depRaw = map['depplandtime']?.toString() ?? '';
      final arrRaw = map['arrplandtime']?.toString() ?? '';

      return TransitResult(
        type: type,
        trainNo: (map['trainno'] ?? '').toString(),
        departureTime: _parseDateTime(depRaw),
        arrivalTime: _parseDateTime(arrRaw),
        durationMinutes: _calcDuration(depRaw, arrRaw),
      );
    } catch (e) {
      debugPrint('Train item parse error: $e / $raw');
      return null;
    }
  }

  TransitResult? _parseBusItem(dynamic raw) {
    try {
      final map = raw as Map<String, dynamic>;

      // 버스 등급: busgradenam (우등, 일반, 프리미엄 등)
      final gradeName = (map['busgradenam'] ?? map['busGradeNm'] ?? '')
          .toString()
          .trim();
      final type =
          gradeName.contains('우등') || gradeName.contains('프리미엄')
              ? TransitType.expressbus
              : TransitType.bus;

      final depRaw = map['depplandtime']?.toString() ?? '';
      final arrRaw = map['arrplandtime']?.toString() ?? '';

      return TransitResult(
        type: type,
        trainNo: (map['busno'] ?? map['routeId'] ?? '').toString(),
        departureTime: _parseDateTime(depRaw),
        arrivalTime: _parseDateTime(arrRaw),
        durationMinutes: _calcDuration(depRaw, arrRaw),
      );
    } catch (e) {
      debugPrint('Bus item parse error: $e / $raw');
      return null;
    }
  }

  TransitType _trainGradeToType(String grade) {
    if (grade.contains('KTX')) return TransitType.ktx;
    if (grade.contains('SRT')) return TransitType.srt;
    if (grade.contains('ITX') ||
        grade.contains('새마을') ||
        grade.contains('SAEMAUL')) {
      return TransitType.itx;
    }
    return TransitType.mugunghwa;
  }

  /// 날짜 → YYYYMMDD
  String _fmtDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// 시각 파싱: "20260318080000" → "08:00"
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
