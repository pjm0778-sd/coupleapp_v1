/// ODsay 열차 터미널 검색어 예외
/// 자동 변환(괄호 제거 + '역' 제거)이 ODsay 역명과 다를 때만 등록
const Map<String, String> odsayTrainSearchExceptions = {
  '여수엑스포역 (KTX)': '여수EXPO',
  '천안아산역 (KTX/SRT)': '천안아산',
  '김천구미역 (KTX)': '김천구미',
  '동탄역 (SRT)': '동탄',
};

/// ODsay 시외버스 터미널 검색어 예외
const Map<String, String> odsayIntercityBusSearchExceptions = {
  '부산종합터미널 (노포)': '부산종합',
  '유스퀘어터미널': '유스퀘어',
  '인천터미널': '인천',
  '동서울터미널': '동서울',
  '서울남부터미널': '남부',
};

/// ODsay 고속버스 터미널 검색어 예외
const Map<String, String> odsayExpressBusSearchExceptions = {
  '부산종합터미널 (노포)': '부산종합',
  '유스퀘어터미널': '유스퀘어',
  '인천터미널': '인천',
};

/// 예매 사이트 기본 URL (딥링크 실패 시 폴백)
const String srtBookingUrl = 'https://etk.srail.kr';
// letskorail.com 경로가 404 — 새 korail.com 메인 예매 페이지 사용
const String korailBookingUrl = 'https://www.korail.com/ticket/main';
const String busBookingUrl = 'https://www.kobus.co.kr';
const String intercityBusBookingUrl = 'https://www.bustago.or.kr';

// ────────────────────────────────────────────────
// 예매 딥링크 URL 빌더
// ────────────────────────────────────────────────

/// SRT 시스템 역코드 (github.com/ryanking13/SRT 기준)
/// 앱 내 전체 역명 → etk.srail.kr dptRsStnCd / arvRsStnCd 값
const Map<String, String> srtStationCodes = {
  '수서역 (SRT)': '0551',
  '동탄역 (SRT)': '0552',
  '평택지제역 (SRT)': '0553',
  '천안아산역 (KTX/SRT)': '0502',
  '오송역 (KTX)': '0297',
  '대전역 (KTX)': '0010',
  '공주역 (KTX)': '0514',
  '익산역 (KTX)': '0030',
  '정읍역 (KTX)': '0033',
  '광주송정역 (KTX)': '0036',
  '나주역 (KTX)': '0037',
  '목포역 (KTX)': '0041',
  '여수엑스포역 (KTX)': '0053',
  '순천역 (KTX)': '0051',
  '김천구미역 (KTX)': '0507',
  '서대구역 (KTX)': '0506',
  '동대구역 (KTX)': '0015',
  '신경주역 (KTX)': '0508',
  '울산역 (KTX)': '0509',
  '포항역 (KTX)': '0515',
  '부산역 (KTX)': '0020',
};

/// Korail 역 코드 (앱 역명 → 4자리 코드)
const Map<String, String> korailStationCodes = {
  '서울역 (KTX)': '0001',
  '용산역': '0002',
  '영등포역': '0003',
  '행신역': '0004',
  '수원역': '0005',
  '오산역': '0006',
  '평택역': '0007',
  '광명역 (KTX)': '0009',
  '천안아산역 (KTX/SRT)': '0010',
  '천안역': '0013',
  '오송역 (KTX)': '0015',
  '대전역 (KTX)': '0020',
  '서대전역': '0021',
  '공주역 (KTX)': '0025',
  '논산역': '0026',
  '김천구미역 (KTX)': '0030',
  '서대구역 (KTX)': '0031',
  '동대구역 (KTX)': '0037',
  '경주역': '0040',
  '신경주역 (KTX)': '0041',
  '울산역 (KTX)': '0043',
  '포항역 (KTX)': '0045',
  '밀양역 (KTX)': '0046',
  '구포역': '0051',
  '부산역 (KTX)': '0052',
  '부전역': '0053',
  '광주송정역 (KTX)': '0065',
  '나주역 (KTX)': '0064',
  '목포역 (KTX)': '0067',
  '여수엑스포역 (KTX)': '0073',
  '순천역 (KTX)': '0071',
  '전주역': '0061',
  '정읍역 (KTX)': '0062',
  '익산역 (KTX)': '0055',
  '강릉역 (KTX)': '0090',
  '청량리역': '0097',
  '상봉역': '0099',
  '원주역': '0086',
  '서원주역': '0087',
};

/// 역명에서 괄호·'역' 제거 → 사이트 검색용 단어 추출
String _stationShortName(String station) =>
    station.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim().replaceFirst(RegExp(r'역$'), '');

/// SRT 예매 URL — 역코드(dptRsStnCd) 기반으로 출발지·도착지 자동 입력
/// pageId + 역코드 포함 → etk.srail.kr 검색결과 직접 진입
String buildSrtBookingUrl({
  required String fromStation,
  required String toStation,
  required DateTime date,
  String? departureTime, // "09:30"
}) {
  final dateStr =
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  // SRT는 HHMMSS (6자리) 형식 — "09:30" → "093000"
  final timeStr = '${(departureTime ?? '00:00').replaceAll(':', '')}00';

  final fromCode = srtStationCodes[fromStation];
  final toCode = srtStationCodes[toStation];

  final params = <String, String>{
    'pageId': 'TK0101010000',
    'isRequest': 'Y',
    'dptDt': dateStr,
    'dptTm': timeStr,
    'chtnDvCd': '1',
    'psgInfoPerPrnb1': '1', // 어른 1명
    'psgInfoPerPrnb2': '0',
    'psgInfoPerPrnb3': '0',
    'psgInfoPerPrnb4': '0',
    'psgInfoPerPrnb5': '0',
    'psgInfoPerPrnb6': '0',
    'locSeatAttCd1': '000',
    'rqSeatAttCd1': '015',
    'trnGpCd': '109', // SRT 열차 그룹 코드
  };

  // 역코드가 있으면 코드 우선, 없으면 역명으로 폴백
  if (fromCode != null) {
    params['dptRsStnCd'] = fromCode;
  } else {
    params['dptRsStnCdNm'] = _stationShortName(fromStation);
  }
  if (toCode != null) {
    params['arvRsStnCd'] = toCode;
  } else {
    params['arvRsStnCdNm'] = _stationShortName(toStation);
  }

  return Uri.https('etk.srail.kr', '/hpg/hra/01/selectScheduleList.do', params)
      .toString();
}

/// KTX(Korail) 예매 URL
/// korail.com 새 URL 구조를 사용 — 역코드 있으면 메인 페이지로, 없으면 null
String? buildKorailBookingUrl({
  required String fromStation,
  required String toStation,
  required DateTime date,
  String? departureTime,
}) {
  final fromCode = korailStationCodes[fromStation];
  final toCode = korailStationCodes[toStation];
  // 역코드 없으면 null → 호출부에서 korailBookingUrl(메인 페이지) 폴백
  if (fromCode == null || toCode == null) return null;

  // korail.com 새 예매 페이지로 연결 (letskorail.com 경로는 404)
  // 파라미터는 구버전 korail 앱 호환 형식 시도
  final dateStr =
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  final hour = (departureTime ?? '00:00').substring(0, 2);

  return Uri.https('www.korail.com', '/ticket/main', {
    'start_code': fromCode,
    'end_code': toCode,
    's_date': dateStr,
    's_time': hour,
    'start_name': _stationShortName(fromStation),
    'end_name': _stationShortName(toStation),
  }).toString();
}
