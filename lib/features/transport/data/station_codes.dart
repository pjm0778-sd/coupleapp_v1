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

/// 예매 사이트 URL
const String srtBookingUrl = 'https://etk.srail.kr';
const String korailBookingUrl = 'https://www.letskorail.com';
const String busBookingUrl = 'https://www.kobus.co.kr';
const String intercityBusBookingUrl = 'https://www.bustago.or.kr';
