import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';
import '../../../core/supabase_client.dart' show supabaseUrl, supabaseAnonKey;

class TransportService {
  // ODsay API는 Supabase Edge Function을 통해 프록시 (CORS 우회 + API 키 서버 관리)
  static const String _proxyBase = '$supabaseUrl/functions/v1/odsay-proxy';

  // SharedPreferences 캐시 키 접두사 (터미널 ID 영구 저장)
  static const String _prefPrefix = 'odsay_id_';

  // 세션 내 메모리 캐시 (SharedPreferences 중복 호출 방지)
  final Map<String, int?> _trainIdCache = {};
  final Map<String, int?> _expBusIdCache = {};
  final Map<String, int?> _intercityBusIdCache = {};

  // 검색 결과 30분 캐시 (같은 구간+날짜 재검색 시 API 호출 0회)
  static const Duration _resultCacheTtl = Duration(minutes: 30);
  final Map<String, _SearchCache> _resultCache = {};

  /// 출발역/터미널 → 도착역/터미널 통합 검색
  Future<TransportSearchResult> search({
    required String fromStation,
    required String toStation,
    required DateTime date,
  }) async {
    // ── 결과 캐시 확인 (30분 유효) ──
    final cacheKey =
        '${fromStation}_${toStation}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final cached = _resultCache[cacheKey];
    if (cached != null && cached.isValid) {
      debugPrint('[ODsay] 캐시 히트: $cacheKey');
      return cached.result;
    }

    _currentSearchDate = date;
    final results = <TransitResult>[];
    String? trainError;
    String? busError;
    bool hasSrtStation = false;

    // ── 기차 (ODsay trainServiceTime) ──
    try {
      final depId = await _getTrainId(fromStation);
      final arrId = await _getTrainId(toStation);
      debugPrint('[ODsay] train IDs: dep=$depId arr=$arrId ($fromStation → $toStation)');
      if (depId != null && arrId != null) {
        final trains = await _fetchTrains(depId, arrId);
        results.addAll(trains);
        if (trains.any((t) => t.type == TransitType.srt)) hasSrtStation = true;
      } else {
        debugPrint('[ODsay] 열차 역 ID 미발견');
      }
    } catch (e) {
      trainError = '열차 정보를 불러오지 못했습니다 ($e)';
      debugPrint('[ODsay] train error: $e');
    }


    // ── 고속버스 (ODsay searchInterBusSchedule, stationClass=4) ──
    try {
      final depId = await _getExpBusId(fromStation);
      final arrId = await _getExpBusId(toStation);
      debugPrint('[ODsay] express bus IDs: dep=$depId arr=$arrId');
      if (depId != null && arrId != null) {
        final buses = await _fetchBuses(depId, arrId, stationClass: 4);
        results.addAll(buses);
      } else {
        debugPrint('[ODsay] 고속버스 터미널 ID 미발견');
      }
    } catch (e) {
      busError = '고속버스 정보를 불러오지 못했습니다 ($e)';
      debugPrint('[ODsay] express bus error: $e');
    }

    // ── 시외버스 (ODsay searchInterBusSchedule, stationClass=6) ──
    try {
      final depId = await _getIntercityBusId(fromStation);
      final arrId = await _getIntercityBusId(toStation);
      debugPrint('[ODsay] intercity bus IDs: dep=$depId arr=$arrId');
      if (depId != null && arrId != null) {
        final buses = await _fetchBuses(depId, arrId, stationClass: 6);
        results.addAll(buses);
      } else {
        debugPrint('[ODsay] 시외버스 터미널 ID 미발견');
      }
    } catch (e) {
      debugPrint('[ODsay] intercity bus error: $e');
    }

    results.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    final searchResult = TransportSearchResult(
      results: results,
      hasSrtStation: hasSrtStation,
      trainError: trainError,
      busError: busError,
    );

    // 결과 캐시 저장
    _resultCache[cacheKey] = _SearchCache(result: searchResult);

    return searchResult;
  }

  // ────────────────────────────────────────────────
  // ODsay 터미널 ID 조회
  // ────────────────────────────────────────────────

  Future<int?> _getTrainId(String stationName) => _getCachedId(
        stationName: stationName,
        endpoint: 'trainTerminals',
        memCache: _trainIdCache,
        searchTerm: odsayTrainSearchExceptions[stationName] ??
            _deriveTrainSearchTerm(stationName),
      );

  Future<int?> _getExpBusId(String stationName) => _getCachedId(
        stationName: stationName,
        endpoint: 'expressBusTerminals',
        memCache: _expBusIdCache,
        searchTerm: odsayExpressBusSearchExceptions[stationName] ??
            _deriveBusSearchTerm(stationName),
      );

  Future<int?> _getIntercityBusId(String stationName) => _getCachedId(
        stationName: stationName,
        endpoint: 'intercityBusTerminals',
        memCache: _intercityBusIdCache,
        searchTerm: odsayIntercityBusSearchExceptions[stationName] ??
            _deriveBusSearchTerm(stationName),
      );

  /// 터미널 ID 3단계 캐시 조회:
  ///  1) 메모리 캐시 → 2) SharedPreferences → 3) ODsay API
  Future<int?> _getCachedId({
    required String stationName,
    required String endpoint,
    required Map<String, int?> memCache,
    required String searchTerm,
  }) async {
    // 1) 메모리 캐시
    if (memCache.containsKey(stationName)) return memCache[stationName];

    // 2) SharedPreferences (앱 재시작 후에도 유효)
    final prefKey = '$_prefPrefix${endpoint}_$stationName';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(prefKey)) {
      final stored = prefs.getInt(prefKey);
      memCache[stationName] = stored;
      debugPrint('[ODsay] prefs 캐시: $endpoint "$stationName" → $stored');
      return stored;
    }

    // 3) API 호출
    final id = await _searchTerminalId(endpoint: endpoint, name: searchTerm);
    memCache[stationName] = id;
    if (id != null) await prefs.setInt(prefKey, id);
    return id;
  }

  Future<int?> _searchTerminalId({
    required String endpoint,
    required String name,
  }) async {
    final uri = Uri.parse(_proxyBase).replace(queryParameters: {
      'endpoint': endpoint,
      'terminalName': name,
    });

    debugPrint('[ODsay] $endpoint?terminalName=$name');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
          'apikey': supabaseAnonKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[ODsay] $endpoint status=${response.statusCode} '
          'body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode != 200) {
        debugPrint('[ODsay] $endpoint HTTP error ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['error'] != null) {
        debugPrint('[ODsay] $endpoint API error: ${body['error']}');
        return null;
      }

      final result = body['result'];
      if (result == null) {
        debugPrint('[ODsay] $endpoint result=null');
        return null;
      }

      // ① trainTerminals: result가 List로 반환
      // e.g., {"result": [{"stationID": 3300128, "stationName": "서울", ...}]}
      if (result is List) {
        if (result.isEmpty) {
          debugPrint('[ODsay] $endpoint "$name" → 검색결과 없음');
          return null;
        }
        final id = (result.first['stationID'] as num?)?.toInt();
        debugPrint('[ODsay] $endpoint "$name" → stationID=$id (${result.length}건)');
        return id;
      }

      if (result is Map) {
        // ② expressBusTerminals / intercityBusTerminals:
        //    result 자체가 터미널 단일 객체 {"stationID": ..., "stationName": ..., ...}
        final directId = (result['stationID'] as num?)?.toInt();
        if (directId != null) {
          debugPrint('[ODsay] $endpoint "$name" → stationID=$directId (direct)');
          return directId;
        }

        // ③ 일부 구버전 응답: {"result": {"station": [...]}}
        final stations = result['station'];
        if (stations is List && stations.isNotEmpty) {
          final id = (stations.first['stationID'] as num?)?.toInt();
          debugPrint('[ODsay] $endpoint "$name" → stationID=$id (station[])');
          return id;
        } else if (stations is Map) {
          final id = (stations['stationID'] as num?)?.toInt();
          debugPrint('[ODsay] $endpoint "$name" → stationID=$id (station{})');
          return id;
        }
      }

      debugPrint('[ODsay] $endpoint "$name" → 파싱 실패 type=${result.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('[ODsay] $endpoint EXCEPTION: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────
  // ODsay 시간표 조회
  // ────────────────────────────────────────────────

  DateTime? _currentSearchDate;

  Future<List<TransitResult>> _fetchTrains(int depId, int arrId) async {
    final uri = Uri.parse(_proxyBase).replace(queryParameters: {
      'endpoint': 'trainServiceTime',
      'startStationID': depId.toString(),
      'endStationID': arrId.toString(),
    });

    debugPrint('[ODsay] trainServiceTime dep=$depId arr=$arrId');
    final response = await http.get(
      uri,
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    debugPrint('[ODsay] trainServiceTime status=${response.statusCode} '
        'body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

    if (response.statusCode != 200) {
      throw Exception('열차 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      debugPrint('[ODsay] trainServiceTime API error: ${body['error']}');
      return [];
    }

    final result = body['result'];
    if (result == null) return [];

    final items = _extractList(result['station']);
    debugPrint('[ODsay] trainServiceTime ${items.length}건');
    return items
        .map((e) => _parseTrainItem(e, filterDate: _currentSearchDate))
        .whereType<TransitResult>()
        .toList();
  }

  Future<List<TransitResult>> _fetchBuses(
    int depId,
    int arrId, {
    required int stationClass,
  }) async {
    final uri = Uri.parse(_proxyBase).replace(queryParameters: {
      'endpoint': 'searchInterBusSchedule',
      'startStationID': depId.toString(),
      'endStationID': arrId.toString(),
      'stationClass': stationClass.toString(),
    });

    debugPrint('[ODsay] searchInterBusSchedule dep=$depId arr=$arrId class=$stationClass');
    final response = await http.get(
      uri,
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    debugPrint('[ODsay] searchInterBusSchedule status=${response.statusCode} '
        'body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

    if (response.statusCode != 200) {
      throw Exception('버스 조회 HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      debugPrint('[ODsay] searchInterBusSchedule API error: ${body['error']}');
      return [];
    }

    final result = body['result'];
    if (result == null) return [];

    final items = _extractList(result['schedule']);
    final isIntercity = stationClass == 6;
    debugPrint('[ODsay] searchInterBusSchedule ${items.length}건 (class=$stationClass)');
    return items
        .map((e) => _parseBusItem(e, isIntercity: isIntercity))
        .whereType<TransitResult>()
        .toList();
  }

  // ────────────────────────────────────────────────
  // 응답 파싱
  // ────────────────────────────────────────────────

  TransitResult? _parseTrainItem(dynamic raw, {DateTime? filterDate}) {
    try {
      final map = raw as Map<String, dynamic>;
      // ODsay는 trainClass 필드 사용 (railName은 없음)
      final trainClass =
          (map['trainClass'] ?? map['railName'] ?? '').toString().toUpperCase();
      final type = _railNameToType(trainClass);

      // runDay 필터링: 선택한 날짜에 운행하지 않는 열차 제외
      if (filterDate != null) {
        final runDay = map['runDay']?.toString() ?? '';
        if (!_matchesRunDay(runDay, filterDate)) return null;
      }

      // ODsay는 "0500" (HHmm 4자리) 또는 "05:00" (HH:mm) 모두 반환 가능
      final depTime = _normalizeTime(map['departureTime']?.toString() ?? '--:--');
      final arrTime = _normalizeTime(map['arrivalTime']?.toString() ?? '--:--');
      // ODsay wasteTime may be int minutes or "HH:MM" duration string
      final wasteRaw = map['wasteTime'];
      final waste = _parseWasteMinutes(wasteRaw) ??
          _calcDurationFromTimeStr(depTime, arrTime);

      // 열차 요금 추출 (fare 배열 또는 단일 값)
      int? fare;
      final fareRaw = map['fare'];
      if (fareRaw is num) {
        fare = fareRaw.toInt();
      } else if (fareRaw is List && fareRaw.isNotEmpty) {
        // fare 배열인 경우 일반실 요금 (첫 번째)
        final first = fareRaw.first;
        if (first is Map) {
          fare = (first['general'] as num?)?.toInt() ??
              (first['fare'] as num?)?.toInt();
        } else if (first is num) {
          fare = first.toInt();
        }
      } else if (fareRaw is Map) {
        // ODsay fare values may be string ("13000") or num
        final generalRaw = fareRaw['general'] ?? fareRaw['fare'];
        if (generalRaw is num) {
          fare = generalRaw.toInt();
        } else if (generalRaw != null) {
          fare = int.tryParse(generalRaw.toString());
        }
      }

      return TransitResult(
        type: type,
        trainNo: map['trainNo']?.toString() ?? '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: waste,
        fare: fare,
      );
    } catch (e) {
      debugPrint('[ODsay] Train parse error: $e / $raw');
      return null;
    }
  }

  TransitResult? _parseBusItem(dynamic raw, {required bool isIntercity}) {
    try {
      final map = raw as Map<String, dynamic>;
      final busClass = (map['busClass'] as num?)?.toInt() ?? 1;
      // busClass: 1=일반, 2=우등, 3=프리미엄
      TransitType type;
      if (isIntercity) {
        type = busClass >= 2 ? TransitType.expressbus : TransitType.intercitybus;
      } else {
        type = busClass >= 2 ? TransitType.expressbus : TransitType.bus;
      }

      // ODsay는 "0600" 또는 "06:00" 형식으로 반환
      final depTime = _normalizeTime(map['departureTime']?.toString() ?? '--:--');
      final waste = (map['wasteTime'] as num?)?.toInt() ?? 0;
      final arrTime = waste > 0 ? _addMinutes(depTime, waste) : depTime;
      final fare = (map['fare'] as num?)?.toInt();

      return TransitResult(
        type: type,
        trainNo: '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: waste,
        fare: fare,
      );
    } catch (e) {
      debugPrint('[ODsay] Bus parse error: $e / $raw');
      return null;
    }
  }

  TransitType _railNameToType(String railName) {
    if (railName.contains('KTX')) return TransitType.ktx;
    if (railName.contains('SRT')) return TransitType.srt;
    if (railName.contains('ITX') || railName.contains('새마을')) {
      return TransitType.itx;
    }
    return TransitType.mugunghwa;
  }

  // ────────────────────────────────────────────────
  // 유틸
  // ────────────────────────────────────────────────

  /// ODsay runDay 필드 기준 운행 여부 확인
  /// runDay 예시: "매일", "월~금", "월,수,금", "토,일", "주말", "평일"
  bool _matchesRunDay(String runDay, DateTime date) {
    if (runDay.isEmpty || runDay == '매일') return true;
    final wd = date.weekday; // 1=월 ~ 7=일
    final isWeekend = wd >= 6; // 토=6, 일=7
    final isWeekday = wd <= 5;

    if (runDay == '평일' || runDay == '월~금') return isWeekday;
    if (runDay == '주말' || runDay == '토,일' || runDay == '토~일') return isWeekend;

    // 요일 개별 매핑
    const dayMap = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
    // "월,수,금" 형식
    if (runDay.contains(',')) {
      final days = runDay.split(',').map((d) => dayMap[d.trim()]).whereType<int>();
      return days.contains(wd);
    }
    // "월~금" 범위 형식 (이미 위에서 처리)
    if (runDay.contains('~')) {
      final parts = runDay.split('~');
      final from = dayMap[parts[0].trim()] ?? 1;
      final to = dayMap[parts[1].trim()] ?? 7;
      return wd >= from && wd <= to;
    }
    // 단일 요일
    return dayMap[runDay.trim()] == wd;
  }

  /// ODsay 시간 정규화: "0500" → "05:00", "05:00" → "05:00"
  String _normalizeTime(String raw) {
    if (raw.length == 4 && !raw.contains(':')) {
      return '${raw.substring(0, 2)}:${raw.substring(2, 4)}';
    }
    return raw;
  }

  String _deriveTrainSearchTerm(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (name.endsWith('역')) name = name.substring(0, name.length - 1);
    return name;
  }

  String _deriveBusSearchTerm(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    for (final suffix in [
      '종합버스터미널', '고속버스터미널', '시외버스터미널', '종합터미널', '버스터미널', '터미널'
    ]) {
      if (name.endsWith(suffix)) {
        return name.substring(0, name.length - suffix.length).trim();
      }
    }
    return name;
  }


  List<dynamic> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    return [data];
  }

  String _addMinutes(String timeStr, int minutes) {
    if (timeStr.length < 5 || minutes == 0) return timeStr;
    final h = int.tryParse(timeStr.substring(0, 2)) ?? 0;
    final m = int.tryParse(timeStr.substring(3, 5)) ?? 0;
    final total = h * 60 + m + minutes;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
  }

  /// ODsay wasteTime: int minutes OR "HH:MM" duration string (e.g. "02:34" = 154분)
  int? _parseWasteMinutes(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String && raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
    }
    return null;
  }

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

  Map<String, String> _authHeaders() {
    return {
      'Authorization':
          'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
      'apikey': supabaseAnonKey,
    };
  }
}

class _SearchCache {
  final TransportSearchResult result;
  final DateTime _createdAt;

  _SearchCache({required this.result}) : _createdAt = DateTime.now();

  bool get isValid =>
      DateTime.now().difference(_createdAt) < TransportService._resultCacheTtl;
}

class TransportSearchResult {
  final List<TransitResult> results;
  final bool hasSrtStation;
  final String? trainError;
  final String? busError;

  const TransportSearchResult({
    required this.results,
    this.hasSrtStation = false,
    this.trainError,
    this.busError,
  });

  List<TransitResult> get trainResults =>
      results.where((r) => r.isRailway).toList();

  List<TransitResult> get busResults =>
      results.where((r) => !r.isRailway).toList();

  bool get hasError => trainError != null || busError != null;

  bool get isEmpty => results.isEmpty;
}
