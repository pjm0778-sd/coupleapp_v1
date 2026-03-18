import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_keys.dart';
import '../models/transit_result.dart';
import '../data/station_codes.dart';

class TransportService {
  static const _base = 'https://api.odsay.com/v1/api';

  // ODsay stationID 캐시
  final Map<String, int?> _trainIdCache = {};
  final Map<String, int?> _expBusIdCache = {};
  final Map<String, int?> _intercityBusIdCache = {};

  /// 출발역/터미널 → 도착역/터미널 통합 검색
  Future<TransportSearchResult> search({
    required String fromStation,
    required String toStation,
    required DateTime date,
  }) async {
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
        debugPrint('[ODsay] 열차 역 ID 미발견: dep=$depId arr=$arrId');
      }
    } catch (e) {
      trainError = '열차 정보를 불러오지 못했습니다 ($e)';
      debugPrint('[ODsay] train error: $e');
    }

    // ── SRT Supabase 보완 (ODsay SRT 미지원 시 폴백) ──
    try {
      final srtList = await _fetchSrtFromSupabase(
        fromStation: fromStation,
        toStation: toStation,
        date: date,
      );
      for (final srt in srtList) {
        // 중복 방지: 같은 열차번호 없을 때만 추가
        if (!results.any(
            (r) => r.trainNo == srt.trainNo && r.type == TransitType.srt)) {
          results.add(srt);
        }
      }
      if (srtList.isNotEmpty) hasSrtStation = true;
    } catch (e) {
      debugPrint('SRT Supabase error: $e');
    }

    // ── SRT 전용 역 배너 ──
    if (srtOnlyStations.contains(fromStation) ||
        srtOnlyStations.contains(toStation)) {
      hasSrtStation = true;
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

    return TransportSearchResult(
      results: results,
      hasSrtStation: hasSrtStation,
      trainError: trainError,
      busError: busError,
    );
  }

  // ────────────────────────────────────────────────
  // ODsay 터미널 ID 조회
  // ────────────────────────────────────────────────

  Future<int?> _getTrainId(String stationName) async {
    if (_trainIdCache.containsKey(stationName)) return _trainIdCache[stationName];
    final term = odsayTrainSearchExceptions[stationName] ??
        _deriveTrainSearchTerm(stationName);
    final id = await _searchTerminalId(endpoint: 'trainTerminals', name: term);
    _trainIdCache[stationName] = id;
    return id;
  }

  Future<int?> _getExpBusId(String stationName) async {
    if (_expBusIdCache.containsKey(stationName)) return _expBusIdCache[stationName];
    final term = odsayExpressBusSearchExceptions[stationName] ??
        _deriveBusSearchTerm(stationName);
    final id = await _searchTerminalId(endpoint: 'expressBusTerminals', name: term);
    _expBusIdCache[stationName] = id;
    return id;
  }

  Future<int?> _getIntercityBusId(String stationName) async {
    if (_intercityBusIdCache.containsKey(stationName)) {
      return _intercityBusIdCache[stationName];
    }
    final term = odsayIntercityBusSearchExceptions[stationName] ??
        _deriveBusSearchTerm(stationName);
    final id =
        await _searchTerminalId(endpoint: 'intercityBusTerminals', name: term);
    _intercityBusIdCache[stationName] = id;
    return id;
  }

  Future<int?> _searchTerminalId({
    required String endpoint,
    required String name,
  }) async {
    // API 키의 '/'가 %2F로 인코딩되지 않도록 URI를 직접 조합
    final uri = Uri.parse(
        '$_base/$endpoint?apiKey=${Uri.encodeComponent(ApiKeys.odsayKey)}&terminalName=${Uri.encodeComponent(name)}');

    debugPrint('[ODsay] $endpoint?terminalName=$name → $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ODsay] $endpoint status=${response.statusCode} body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode != 200) {
        debugPrint('[ODsay] $endpoint HTTP error ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // ODsay 에러 코드 체크
      if (body['error'] != null) {
        debugPrint('[ODsay] $endpoint API error: ${body['error']}');
        return null;
      }

      final result = body['result'];
      if (result == null) {
        debugPrint('[ODsay] $endpoint result=null (no route?)');
        return null;
      }

      final stations = result['station'];
      if (stations == null) {
        debugPrint('[ODsay] $endpoint station=null, result keys: ${result.keys.toList()}');
        return null;
      }

      if (stations is List && stations.isNotEmpty) {
        final id = (stations.first['stationID'] as num?)?.toInt();
        debugPrint('[ODsay] $endpoint "$name" → stationID=$id (${stations.length}건)');
        return id;
      } else if (stations is Map) {
        final id = (stations['stationID'] as num?)?.toInt();
        debugPrint('[ODsay] $endpoint "$name" → stationID=$id (single)');
        return id;
      }
      debugPrint('[ODsay] $endpoint stations type=${stations.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('[ODsay] $endpoint EXCEPTION: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────
  // ODsay 시간표 조회
  // ────────────────────────────────────────────────

  Future<List<TransitResult>> _fetchTrains(int depId, int arrId) async {
    final uri = Uri.parse(
        '$_base/trainServiceTime?apiKey=${Uri.encodeComponent(ApiKeys.odsayKey)}&startStationID=$depId&endStationID=$arrId');

    debugPrint('[ODsay] trainServiceTime dep=$depId arr=$arrId');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    debugPrint('[ODsay] trainServiceTime status=${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

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
    return items.map(_parseTrainItem).whereType<TransitResult>().toList();
  }

  Future<List<TransitResult>> _fetchBuses(
    int depId,
    int arrId, {
    required int stationClass,
  }) async {
    final uri = Uri.parse(
        '$_base/searchInterBusSchedule?apiKey=${Uri.encodeComponent(ApiKeys.odsayKey)}&startStationID=$depId&endStationID=$arrId&stationClass=$stationClass');

    debugPrint('[ODsay] searchInterBusSchedule dep=$depId arr=$arrId class=$stationClass');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    debugPrint('[ODsay] searchInterBusSchedule status=${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

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
  // SRT Supabase 폴백
  // ────────────────────────────────────────────────

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

    final weekday = date.weekday;
    final isWeekend = weekday >= 5;

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

  // ────────────────────────────────────────────────
  // 응답 파싱
  // ────────────────────────────────────────────────

  TransitResult? _parseTrainItem(dynamic raw) {
    try {
      final map = raw as Map<String, dynamic>;
      final railName =
          (map['railName'] ?? map['trainClass'] ?? '').toString().toUpperCase();
      final type = _railNameToType(railName);
      final depTime = map['departureTime']?.toString() ?? '--:--';
      final arrTime = map['arrivalTime']?.toString() ?? '--:--';
      final waste = (map['wasteTime'] as num?)?.toInt() ?? 0;

      return TransitResult(
        type: type,
        trainNo: map['trainNo']?.toString() ?? '',
        departureTime: depTime,
        arrivalTime: arrTime,
        durationMinutes: waste,
      );
    } catch (e) {
      debugPrint('Train parse error: $e / $raw');
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

      final depTime = map['departureTime']?.toString() ?? '--:--';
      final waste = (map['wasteTime'] as num?)?.toInt() ?? 0;
      final arrTime = _addMinutes(depTime, waste);
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
      debugPrint('Bus parse error: $e / $raw');
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

  String _stripStationSuffix(String stationName) {
    var name = stationName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (name.endsWith('역')) name = name.substring(0, name.length - 1);
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
