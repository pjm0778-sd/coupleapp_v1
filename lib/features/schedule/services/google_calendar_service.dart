import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

/// google_sign_in의 액세스 토큰을 googleapis에 전달하기 위한 HTTP 클라이언트
class _AuthClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _AuthClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleCalendarService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [gcal.CalendarApi.calendarReadonlyScope],
  );

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<gcal.CalendarApi> _getApi() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) throw Exception('로그인이 취소되었습니다');

    final auth = await account.authentication;
    if (auth.accessToken == null) throw Exception('액세스 토큰을 가져올 수 없습니다');

    final client = _AuthClient(http.Client(), {
      'Authorization': 'Bearer ${auth.accessToken}',
    });
    return gcal.CalendarApi(client);
  }

  Future<List<Map<String, dynamic>>> getMonthEvents(
    int year,
    int month,
  ) async {
    final api = await _getApi();

    final timeMin = DateTime(year, month, 1).toUtc();
    final timeMax = DateTime(year, month + 1, 1).toUtc();

    final events = await api.events.list(
      'primary',
      timeMin: timeMin,
      timeMax: timeMax,
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: 250,
    );

    final result = <Map<String, dynamic>>[];

    for (final e in (events.items ?? [])) {
      if (e.summary == null) continue;

      String? startDateStr;
      String? endDateStr;
      String? startTimeStr;
      String? endTimeStr;

      if (e.start?.date != null) {
        // 하루종일 일정: end.date는 exclusive (다음날)이므로 -1일
        startDateStr = _fmtDate(e.start!.date!);
        final actualEnd = e.end!.date!.subtract(const Duration(days: 1));
        endDateStr = _fmtDate(actualEnd);
      } else if (e.start?.dateTime != null) {
        // 시간 지정 일정
        final st = e.start!.dateTime!.toLocal();
        final et = e.end!.dateTime!.toLocal();
        startDateStr = _fmtDate(st);
        endDateStr = _fmtDate(et);
        startTimeStr = _fmtTime(st);
        endTimeStr = _fmtTime(et);
      }

      if (startDateStr == null) continue;

      final item = <String, dynamic>{
        'start_date': startDateStr,
        'end_date': endDateStr ?? startDateStr,
        'work_type': e.summary,
        'color_hex': _colorIdToHex(e.colorId),
      };
      if (startTimeStr != null) item['start_time'] = startTimeStr;
      if (endTimeStr != null) item['end_time'] = endTimeStr;

      result.add(item);
    }

    return result;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Google Calendar colorId → hex 변환
  String _colorIdToHex(String? colorId) {
    const colors = {
      '1': '#AC725E',
      '2': '#D06B64',
      '3': '#F83A22',
      '4': '#FA573C',
      '5': '#FF7537',
      '6': '#FFAD46',
      '7': '#42D692',
      '8': '#16A765',
      '9': '#7BD148',
      '10': '#B3DC6C',
      '11': '#9FC6E7',
    };
    return colors[colorId] ?? '#4285F4';
  }
}
