import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_keys.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';

/// 역 코드 정보 (GetCtyAcctoTrainSttnList 응답)
class _StationNode {
  final String nodeId;
  final String nodeName;
  const _StationNode(this.nodeId, this.nodeName);
}

class TransportService {
  /// 시도 코드별 역 목록 캐시 (앱 세션 내)
  final Map<String, List<_StationNode>> _stationCache = {};

  /// 역 표시명 → nodeId 캐시
  final Map<String, String?> _nodeIdCache = {};

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

    // ── SRT 전용 역 체크 ──
    if (srtOnlyStations.contains(fromStation) ||
        srtOnlyStations.contains(toStation)) {
      hasSrtStation = true;
    }

    // ── TAGO 열차 조회 ──
    final isBusOnlyDep = isBusOnly(fromStation);
    final isBusOnlyArr = isBusOnly(toStation);
    final isSrtOnly = srtOnlyStations.contains(fromStation) ||
        srtOnlyStations.contains(toStation);

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
            trainError = '역 코드를 찾을 수 없습니다 (${depNodeId == null ? fromStation : toStation})';
          }
        } catch (e) {
          trainError = e.toString();
          debugPrint('TAGO TrainInfo API error: $e');
        }
      }
    }

    // ── 고속버스 조회 ──
    final depBus = busTerminalCodes[fromStation];
    final arrBus = busTerminalCodes[toStation];

    if (depBus != null && arrBus != null) {
      if (!ApiKeys.isConfigured) {
        busError = '버스 API 키가 설정되지 않았습니다';
      } else {
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
    }

    results.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return TransportSearchResult(
      results: results,
      hasSrtStation: hasSrtStation,
      trainError: trainError,
      busError: busError,
    );
  }

  /// 역 표시명 → TAGO nodeId 조회 (캐시 활용)
  Future<String?> _getNodeId(String stationName) async {
    if (_nodeIdCache.containsKey(stationName)) {
      return _nodeIdCache[stationName];
    }

    // 예외 매핑 또는 자동 변환으로 API nodename 결정
    final apiName = stationApiNameExceptions[stationName] ??
        _deriveApiName(stationName);

    // 도시명 추출 (역명 앞부분)
    final cityName = _extractCityName(apiName);
    final cityCode = cityProvinceCodes[cityName];

    if (cityCode == null) {
      debugPrint('cityCode not found for: $cityName (from $stationName)');
      _nodeIdCache[stationName] = null;
      return null;
    }

    // 시도 코드별 역 목록 조회
    final stations = await _getProvinceStations(cityCode);

    // nodename 매칭
    final match = stations.where((s) => s.nodeName == apiName).firstOrNull;
    _nodeIdCache[stationName] = match?.nodeId;
    return match?.nodeId;
  }

  /// 앱 표시명 → API nodename 자동 변환
  /// 예) '서울역 (KTX)' → '서울', '부산역 (KTX)' → '부산'
  String _deriveApiName(String stationName) {
    // 괄호 내용 제거: '서울역 (KTX)' → '서울역'
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    // '역' 접미사 제거
    if (name.endsWith('역')) name = name.substring(0, name.length - 1);
    return name;
  }

  /// API nodename에서 도시명 추출
  /// 예) '서울' → '서울', '동대구' → '대구', '광주송정' → '광주'
  String _extractCityName(String apiName) {
    // 광역시/특별시 직접 매핑
    const directMatch = {
      '서울': '서울', '수서': '서울',
      '부산': '부산', '동부산': '부산',
      '동대구': '대구', '대구': '대구', '서대구': '대구',
      '인천': '인천',
      '광주송정': '광주', '광주': '광주',
      '대전': '대전', '서대전': '대전',
      '울산': '울산',
    };
    if (directMatch.containsKey(apiName)) return directMatch[apiName]!;

    // 도 단위: cityProvinceCodes 키 순서로 접두사 매칭
    for (final city in cityProvinceCodes.keys) {
      if (apiName.startsWith(city)) return city;
    }

    // 기타: 첫 2글자로 도시 추정
    if (apiName.length >= 2) {
      final prefix = apiName.substring(0, 2);
      if (cityProvinceCodes.containsKey(prefix)) return prefix;
    }

    return apiName;
  }

  /// 시도 코드 → 역 목록 조회 (GetCtyAcctoTrainSttnList)
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
    final items = _extractItems1613(
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
    final items = _extractItems1613(
      body['response']?['body'] as Map<String, dynamic>? ?? {},
    );

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

  /// 1613000 API 공통 items 추출: item 이 1건=Map, 여러 건=List
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

      // 열차 종별: traingradename (예: "KTX", "무궁화호", "ITX-새마을")
      final grade = (map['traingradename'] ?? '').toString().toUpperCase();
      final type = _trainGradeToType(grade);

      // 출발/도착 시각: depplandtime / arrplandtime (YYYYMMDDHHmmss)
      final depRaw = map['depplandtime']?.toString() ?? '';
      final arrRaw = map['arrplandtime']?.toString() ?? '';

      final depTime = _parseDateTime(depRaw);
      final arrTime = _parseDateTime(arrRaw);
      final duration = _calcDuration(depRaw, arrRaw);

      // 열차번호
      final trainNo = (map['trainno'] ?? '').toString();

      return TransitResult(
        type: type,
        trainNo: trainNo,
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: duration,
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
      final duration = _calcBusDuration(depTime, arrTime);

      return TransitResult(
        type: type,
        trainNo: map['routeId']?.toString() ?? '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: duration,
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
