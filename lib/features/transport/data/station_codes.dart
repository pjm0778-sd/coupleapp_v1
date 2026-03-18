/// TAGO 1613000/TrainInfo API 역 코드 조회용 시도 코드
/// GetCtyAcctoTrainSttnList 파라미터: cityCode
const Map<String, String> cityProvinceCodes = {
  // 특별/광역시
  '서울': '11',
  '부산': '21',
  '대구': '22',
  '인천': '23',
  '광주': '24',
  '대전': '25',
  '울산': '26',
  // 도
  '경기': '31',
  '강원': '32',
  '충북': '33',
  '충남': '34',
  '전북': '35',
  '전남': '36',
  '경북': '37',
  '경남': '38',
  '제주': '39',
};

/// SRT 전용 역 (TAGO KORAIL API 미지원 → etk.srail.kr 링크 제공)
const Set<String> srtOnlyStations = {
  '수서역 (SRT)',
  '판교역 (SRT)',
  '평택지제역 (SRT)',
};

/// 역 표시명 → API nodename 예외 매핑
/// 자동 변환(괄호 제거 + '역' 제거)이 실제 API명과 다를 때만 등록
const Map<String, String> stationApiNameExceptions = {
  '여수엑스포역 (KTX)': '여수EXPO',
  '천안아산역 (KTX/SRT)': '천안아산',
};

/// 버스/터미널 전용 역 목록 (열차 API 조회 불필요)
const Set<String> busOnlyStations = {
  '동서울터미널',
  '서울남부터미널',
  '부산종합터미널 (노포)',
  '대구서부터미널',
  '유스퀘어터미널',
  '대전복합터미널',
  '울산시외버스터미널',
  '수원버스터미널',
  '성남종합터미널',
  '평택버스터미널',
  '천안종합터미널',
  '원주시외버스터미널',
  '춘천고속버스터미널',
  '강릉시외버스터미널',
  '동해버스터미널',
  '청주고속버스터미널',
  '충주버스터미널',
  '제천시외버스터미널',
  '전주고속버스터미널',
  '군산버스터미널',
  '목포버스터미널',
  '여수시외버스터미널',
  '순천종합버스터미널',
  '창원종합터미널',
  '진주시외버스터미널',
  '포항시외버스터미널',
  '경주시외버스터미널',
  '구미버스터미널',
  '안동버스터미널',
  '인천터미널',
};

/// 터미널명 → GetExpBusTrminlList 검색어 예외
/// 자동 변환(접미사 제거)이 API 검색과 맞지 않는 경우만 등록
const Map<String, String> busTerminalSearchExceptions = {
  '부산종합터미널 (노포)': '노포',
  '유스퀘어터미널': '유스퀘어',
  '인천터미널': '인천',
};

/// 버스/공항 전용 여부
bool isBusOnly(String stationName) => busOnlyStations.contains(stationName);

/// 예매 사이트 URL
const String srtBookingUrl = 'https://etk.srail.kr';
const String korailBookingUrl = 'https://www.letskorail.com';
const String busBookingUrl = 'https://www.kobus.co.kr';
