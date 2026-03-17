/// data.go.kr 공공데이터 포털 API 키 설정
///
/// 사용 방법:
/// 1. https://www.data.go.kr 접속
/// 2. "한국철도공사_기차역별 열차 시간표 조회 서비스" 활용 신청
/// 3. "고속버스통합예매 (버스 시간표)" 활용 신청
/// 4. 발급받은 Encoding 키를 아래에 입력
class ApiKeys {
  /// data.go.kr 공공데이터 포털 서비스 키 (인코딩)
  static const String dataGoKr = 'YOUR_DATA_GO_KR_API_KEY_HERE';

  static bool get isConfigured => dataGoKr != 'YOUR_DATA_GO_KR_API_KEY_HERE';
}
