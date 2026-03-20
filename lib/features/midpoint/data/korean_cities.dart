/// 한국 주요 도시 DB
/// dateScore: 연인 데이트 적합도 1~5 (관광지·분위기·명소 기준)
class KoreanCity {
  final String name;
  final double lat;
  final double lng;
  final int dateScore; // 1~5

  const KoreanCity(this.name, this.lat, this.lng, {this.dateScore = 3});
}

const kKoreanCities = [
  // ── 수도권 ──────────────────────────────────────
  KoreanCity('서울',  37.5665, 126.9780, dateScore: 5),
  KoreanCity('인천',  37.4563, 126.7052, dateScore: 3),
  KoreanCity('수원',  37.2636, 127.0286, dateScore: 3),
  KoreanCity('성남',  37.4196, 127.1268, dateScore: 3),
  KoreanCity('용인',  37.2411, 127.1776, dateScore: 2),
  KoreanCity('평택',  36.9921, 127.1130, dateScore: 2),
  KoreanCity('양평',  37.4917, 127.4875, dateScore: 3),
  KoreanCity('가평',  37.8315, 127.5098, dateScore: 4),

  // ── 충청권 ──────────────────────────────────────
  KoreanCity('천안',  36.8151, 127.1139, dateScore: 2),
  KoreanCity('대전',  36.3504, 127.3845, dateScore: 3),
  KoreanCity('세종',  36.4801, 127.2889, dateScore: 2),
  KoreanCity('청주',  36.6424, 127.4890, dateScore: 2),
  KoreanCity('충주',  36.9910, 127.9259, dateScore: 3),
  KoreanCity('제천',  37.1323, 128.1909, dateScore: 3),
  KoreanCity('홍성',  36.6010, 126.6610, dateScore: 2),
  KoreanCity('공주',  36.4465, 127.1194, dateScore: 3),
  KoreanCity('논산',  36.1870, 127.0991, dateScore: 2),

  // ── 전라권 ──────────────────────────────────────
  KoreanCity('전주',  35.8242, 127.1480, dateScore: 5),
  KoreanCity('익산',  35.9482, 126.9545, dateScore: 2),
  KoreanCity('군산',  35.9679, 126.7368, dateScore: 3),
  KoreanCity('광주',  35.1595, 126.8526, dateScore: 3),
  KoreanCity('목포',  34.8118, 126.3922, dateScore: 3),
  KoreanCity('여수',  34.7604, 127.6622, dateScore: 5),
  KoreanCity('순천',  34.9506, 127.4874, dateScore: 4),
  KoreanCity('남원',  35.4164, 127.3900, dateScore: 3),

  // ── 경상권 ──────────────────────────────────────
  KoreanCity('대구',  35.8714, 128.6014, dateScore: 3),
  KoreanCity('구미',  36.1195, 128.3446, dateScore: 2),
  KoreanCity('김천',  36.1396, 128.1135, dateScore: 2),
  KoreanCity('안동',  36.5684, 128.7294, dateScore: 4),
  KoreanCity('영주',  36.8057, 128.6236, dateScore: 3),
  KoreanCity('경주',  35.8562, 129.2247, dateScore: 5),
  KoreanCity('포항',  36.0190, 129.3435, dateScore: 3),
  KoreanCity('부산',  35.1796, 129.0756, dateScore: 5),
  KoreanCity('울산',  35.5384, 129.1135, dateScore: 2),
  KoreanCity('창원',  35.2280, 128.6814, dateScore: 2),
  KoreanCity('진주',  35.1800, 128.1070, dateScore: 3),
  KoreanCity('통영',  34.8544, 128.4330, dateScore: 5),

  // ── 강원권 ──────────────────────────────────────
  KoreanCity('춘천',  37.8813, 127.7300, dateScore: 4),
  KoreanCity('원주',  37.3422, 127.9202, dateScore: 3),
  KoreanCity('강릉',  37.7519, 128.8761, dateScore: 4),
  KoreanCity('속초',  38.2070, 128.5918, dateScore: 4),
  KoreanCity('고성',  38.3800, 128.4700, dateScore: 3),
  KoreanCity('동해',  37.5244, 129.1141, dateScore: 3),
  KoreanCity('태백',  37.1641, 128.9856, dateScore: 3),
];
