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

/// 앱 표시명 → 고속버스 터미널 코드 매핑
/// API: https://apis.data.go.kr/1613000/ExpBusInfoService/getExpBusTrminlSchdl
const Map<String, String> busTerminalCodes = {
  '동서울터미널': '002',
  '서울남부터미널': '003',
  '부산종합터미널 (노포)': '020',
  '대구서부터미널': '017',
  '유스퀘어터미널': '025',
  '대전복합터미널': '009',
  '울산시외버스터미널': '062',
  '수원버스터미널': '007',
  '성남종합터미널': '040',
  '평택버스터미널': '016',
  '천안종합터미널': '026',
  '원주시외버스터미널': '033',
  '춘천고속버스터미널': '060',
  '강릉시외버스터미널': '057',
  '동해버스터미널': '056',
  '청주고속버스터미널': '023',
  '충주버스터미널': '034',
  '제천시외버스터미널': '052',
  '전주고속버스터미널': '041',
  '군산버스터미널': '044',
  '목포버스터미널': '045',
  '여수시외버스터미널': '048',
  '순천종합버스터미널': '049',
  '창원종합터미널': '089',
  '진주시외버스터미널': '069',
  '포항시외버스터미널': '071',
  '경주시외버스터미널': '058',
  '구미버스터미널': '070',
  '안동버스터미널': '064',
  '인천터미널': '006',
};

/// 버스/공항 전용 여부 (역 API 조회 불필요)
bool isBusOnly(String stationName) {
  return busTerminalCodes.containsKey(stationName) &&
      !stationApiNameExceptions.containsKey(stationName) &&
      !srtOnlyStations.contains(stationName);
}

/// 예매 사이트 URL
const String srtBookingUrl = 'https://etk.srail.kr';
const String korailBookingUrl = 'https://www.letskorail.com';
const String busBookingUrl = 'https://www.kobus.co.kr';
