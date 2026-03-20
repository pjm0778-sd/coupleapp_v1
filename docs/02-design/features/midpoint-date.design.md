# Design: midpoint-date (중간지점 데이트 추천)

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | 장거리 커플이 만날 장소 선정 시 각자 따로 검색하고, 이동시간 불균형 발생 |
| **Solution** | 출발지 + 대중교통/자차 2택 → Claude AI 중간지점 추론 → 경로·비용·장소를 한 화면에 |
| **Function UX Effect** | 입력(3단계) → 로딩(병렬 API) → 도시 카드 스크롤 → 경로 비교표 + 지도 + 장소 목록 |
| **Core Value** | 공평한 중간지점 + 데이트 코스 원스톱 제공 |

---

## 1. 아키텍처 개요

```
Flutter App
  MidpointSearchScreen   ─── MidpointResultScreen
          │                          │
          ▼                          ▼
    MidpointService (orchestrator)
     ├─ kakao-place-search (기존)   ← 출발지 geocoding + 장소 검색
     ├─ claude-midpoint (신규)      ← 중간지점 도시 추론
     ├─ naver-directions-proxy (신규) ← 자차 경로·비용 계산
     └─ odsay-proxy (기존 + subway 추가) ← 대중교통 시간·요금
```

### 신규 Edge Functions
| 함수명 | 역할 |
|--------|------|
| `claude-midpoint` | Claude API 호출 → 중간지점 도시 2~3곳 + 이유 반환 |
| `naver-directions-proxy` | Naver Directions 5 API 프록시 → 자동차 경로 정보 |

### 기존 Edge Functions 수정
| 함수명 | 변경 내용 |
|--------|----------|
| `kakao-place-search` | category 검색 모드 추가 (`mode=category` 파라미터) |
| `odsay-proxy` | `searchPubTransPathT` whitelist 추가 (지하철 경로) |

---

## 2. 데이터 모델

### 2.1 입력 모델 (`midpoint_input.dart`)
```dart
enum TransportMode { publicTransit, car }
enum CarType { normal, electric }
enum DateTheme { date, travel, simple }

class MidpointSearchInput {
  final String myOrigin;           // "서울 강남구"
  final String partnerOrigin;      // "부산 해운대구"
  final TransportMode myMode;
  final CarType? myCarType;        // null if publicTransit
  final TransportMode partnerMode;
  final CarType? partnerCarType;
  final DateTheme theme;
}
```

### 2.2 결과 모델 (`midpoint_result.dart`)
```dart
class MidpointCity {
  final String name;               // "대전"
  final String reason;             // Claude 생성 추천 이유
  final double lat;
  final double lng;
  final int estimatedMinutesA;     // Claude 추정 이동시간 (분)
  final int estimatedMinutesB;
}

class RouteInfo {
  final String originName;
  final TransportMode mode;
  final String transitLabel;       // "지하철", "KTX", "고속버스", "일반차", "전기차"
  final double distanceKm;
  final int durationMinutes;
  final int estimatedCost;         // 원
  final bool isEstimated;          // true = Claude 추정값 폴백 (ODsay 정보 없음)
  final String? estimatedNote;     // "이 지역은 정확한 대중교통 정보를 제공하기 어렵습니다."
}

class NearbyPlace {
  final String name;
  final String category;           // "음식점", "카페", "관광명소"
  final double lat;
  final double lng;
  final String? kakaoUrl;
}

class MidpointResult {
  final MidpointCity city;
  final RouteInfo myRoute;
  final RouteInfo partnerRoute;
  final List<NearbyPlace> nearbyPlaces;
}
```

---

## 3. 서비스 설계

### 3.1 MidpointService 흐름
```
search(input) async:
  1. geocodeOrigins(myOrigin, partnerOrigin)  ← kakao-place-search 병렬 2회
  2. inferMidpoints(input, myLatLng, partnerLatLng)  ← claude-midpoint 1회
  3. For each midpoint city (최대 3곳) - 병렬:
     a. geocodeMidpoint(city.name)  ← kakao-place-search
     b. fetchMyRoute(myOrigin, midpointLatLng, myMode)
     c. fetchPartnerRoute(partnerOrigin, midpointLatLng, partnerMode)
     d. fetchNearbyPlaces(midpointLatLng, theme)  ← kakao-place-search category
  4. return List<MidpointResult>
```

### 3.2 교통수단별 경로 조회 로직

#### 자차
```
fetchCarRoute(origin, destination, carType):
  → naver-directions-proxy → 거리/시간/통행료
  → 비용 계산 (carType 기준)
```

#### 대중교통 — 폴백 체인 방식
거리 기반 분기가 아니라 **순서대로 시도 → 결과 없으면 다음으로**:

```
fetchTransitRoute(originLatLng, destinationLatLng, distanceKm, claudeEstimateMinutes):

  results = []

  // 1차: 지하철 통합경로 (ODsay searchPubTransPathT)
  //      좌표 기반이므로 역 없어도 API는 호출 가능
  //      BUT 환승 복잡도 높고 장거리엔 부적합 → 60분 이내 경로만 수용
  subwayResult = await trySubway(originLatLng, destinationLatLng)
  if subwayResult.found && subwayResult.durationMin <= 60:
    results.add(subwayResult)

  // 2차: 열차 (ODsay trainServiceTime)
  //      역명으로 stationID 조회 → 미발견 시 null 반환 → 건너뜀
  trainResult = await tryTrain(originCity, destinationCity)
  if trainResult.found:
    results.add(trainResult)

  // 3차: 고속버스 (ODsay searchInterBusSchedule)
  //      터미널명으로 stationID 조회 → 미발견 시 null 반환 → 건너뜀
  busResult = await tryBus(originCity, destinationCity)
  if busResult.found:
    results.add(busResult)

  // 결과 선택: 가장 빠른 수단 우선
  if results.isNotEmpty:
    return results.reduce((a, b) => a.durationMin < b.durationMin ? a : b)

  // 모두 실패 → Claude 추정값 폴백
  return TransitRoute.estimated(
    durationMinutes: claudeEstimateMinutes,
    label: '대중교통 (추정)',
    note: '이 지역은 정확한 대중교통 정보를 제공하기 어렵습니다.',
  )
```

**distance 계산**: 두 좌표 간 Haversine 공식 (Flutter 클라이언트에서 계산)

#### 폴백 우선순위 요약
| 시도 순서 | 수단 | 수용 조건 | 실패 기준 |
|---------|------|---------|---------|
| 1 | 지하철 (searchPubTransPathT) | 결과 시간 ≤ 60분 | 경로 없음 OR 시간 초과 |
| 2 | 열차/KTX (trainServiceTime) | 역 stationID 발견 | stationID null |
| 3 | 고속버스 (searchInterBusSchedule) | 터미널 stationID 발견 | stationID null |
| 최종 | Claude 추정값 폴백 | 항상 | - |

> **핵심 원칙**: ODsay stationID 조회 실패(null)는 이미 TransportService에서 처리되고 있음 (기존 패턴 재사용). Claude가 이미 `estimatedMinutesA/B`를 반환하므로 폴백 데이터는 항상 존재.

### 3.3 NaverDirectionsService (`naver_directions_service.dart`)
```dart
class NaverDirectionsService {
  // Supabase Edge Function 프록시 경유
  static const String _endpoint = '$supabaseUrl/functions/v1/naver-directions-proxy';

  Future<DirectionsResult> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // GET /functions/v1/naver-directions-proxy
    //   ?start={lng},{lat}&goal={lng},{lat}&option=trafast
    // Response: { distance, duration, tollFare }
  }
}

class DirectionsResult {
  final double distanceKm;
  final int durationMinutes;
  final int tollFare;              // 고속도로 통행료 (원)

  int estimatedFuelCost(CarType type) {
    return type == CarType.electric
        ? (distanceKm / 6 * 300).round()
        : (distanceKm / 12 * 1700).round();
  }

  int totalCost(CarType type) => estimatedFuelCost(type) + tollFare;
}
```

---

## 4. Edge Function 설계

### 4.1 `claude-midpoint/index.ts` (신규)

**요청**: `POST /functions/v1/claude-midpoint`
```json
{
  "myOrigin": "서울 강남구",
  "partnerOrigin": "부산 해운대구",
  "myMode": "publicTransit",
  "partnerMode": "car",
  "partnerCarType": "normal",
  "theme": "date"
}
```

**Claude 프롬프트**:
```
당신은 한국 커플 여행 전문가입니다.
두 사람이 공평하게 이동할 수 있는 중간지점 도시를 추천해주세요.

- A 출발지: {myOrigin} / 교통수단: {myMode}
- B 출발지: {partnerOrigin} / 교통수단: {partnerMode}
- 테마: {theme}

조건:
1. 두 사람의 예상 이동시간이 최대한 비슷할 것
2. 테마에 맞는 도시 (date: 카페·맛집 많은 도시, travel: 관광지, simple: 지리적 중간)
3. 한국 내 도시만 추천

JSON 형식으로만 응답:
{
  "cities": [
    {
      "name": "도시명",
      "reason": "추천 이유 (2문장 이내)",
      "estimatedMinutesA": 90,
      "estimatedMinutesB": 85
    }
  ]
}
```

**응답**:
```json
{
  "cities": [
    { "name": "대전", "reason": "KTX로 A는 50분, B는 자차로 약 1시간 30분으로 가장 균형잡힌 중간 지점입니다. 성심당 등 유명 카페·빵집이 많아 데이트 코스로 제격입니다.", "estimatedMinutesA": 50, "estimatedMinutesB": 90 },
    { "name": "천안", "reason": "...", "estimatedMinutesA": 40, "estimatedMinutesB": 110 }
  ]
}
```

**환경변수**: `CLAUDE_API_KEY` (Supabase secret)
**모델**: `claude-haiku-4-5-20251001` (속도 우선, 비용 절감)

---

### 4.2 `naver-directions-proxy/index.ts` (신규)

**요청**: `GET /functions/v1/naver-directions-proxy?start={lng,lat}&goal={lng,lat}`

**Naver Directions 5 연동**:
- Endpoint: `https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving`
- Headers: `X-NCP-APIGW-API-KEY-ID`, `X-NCP-APIGW-API-KEY`
- option: `trafast` (실시간 빠른 경로)

**응답**:
```json
{
  "distanceKm": 327.4,
  "durationMinutes": 178,
  "tollFare": 9200
}
```

**환경변수**: `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`

---

### 4.3 `kakao-place-search/index.ts` 수정 (category 모드 추가)

**기존**: `?query=...` → keyword 검색
**추가**: `?mode=category&category=FD6&x={lng}&y={lat}&radius=5000`

```typescript
// category 검색 분기 추가
if (mode === 'category') {
  const categoryUrl = `https://dapi.kakao.com/v2/local/search/category.json`
    + `?category_group_code=${category}&x=${x}&y=${y}&radius=${radius}&size=10&sort=distance`
  // ...
}
```

**카테고리 코드**:
| 테마 | 카테고리 |
|------|---------|
| date | FD6 (음식점), CE7 (카페) |
| travel | AT4 (관광명소), AD5 (숙박) |
| simple | FD6 (음식점) |

---

### 4.4 `odsay-proxy/index.ts` 수정 (subway whitelist 추가)

```typescript
// 허용 엔드포인트에 추가
const ALLOWED = [
  'trainTerminals', 'expressBusTerminals', 'intercityBusTerminals',
  'trainServiceTime', 'searchInterBusSchedule',
  'searchPubTransPathT',   // ← 추가 (지하철 통합경로)
]
```

**searchPubTransPathT 파라미터**: `sx, sy, ex, ey` (WGS84 소수점 좌표)
**응답 파싱 대상**: `result.path[0].info.totalTime`, `result.path[0].info.payment`

---

## 5. 화면 설계

### 5.1 파일 구조
```
lib/features/midpoint/
  models/
    midpoint_input.dart
    midpoint_result.dart
  services/
    midpoint_service.dart
    naver_directions_service.dart
  screens/
    midpoint_search_screen.dart    ← 입력 3단계
    midpoint_result_screen.dart    ← 결과
  widgets/
    origin_input_widget.dart       ← 출발지 자동완성
    transport_selector_widget.dart ← 대중교통/자차 선택 + 자차 세부
    midpoint_city_card.dart        ← 도시 카드 (가로 스크롤)
    route_comparison_table.dart    ← 양측 경로 비교표
    nearby_places_list.dart        ← 장소 목록
    midpoint_map_widget.dart       ← flutter_map 지도
```

### 5.2 MidpointSearchScreen — 입력 3단계

**Step 1: 출발지 입력**
```
[내 출발지       🔍]   ← 입력 시 kakao-place-search 자동완성
[상대방 출발지   🔍]
```

**Step 2: 교통수단 선택 (각자)**
```
나의 교통수단:
  [🚇 대중교통]  [🚗 자차]      ← 선택 토글

자차 선택 시 하위 옵션 표시:
  [⛽ 일반차]  [⚡ 전기차]

상대방 교통수단:  (동일 구조)
```

**Step 3: 테마 선택**
```
  [💑 데이트]  [✈️ 여행]  [📍 중간지점만]
```

→ `[중간지점 찾기]` 버튼 → 로딩 (Lottie/CircularProgressIndicator)

### 5.3 MidpointResultScreen — 결과

```
┌─────────────────────────────────┐
│  추천 중간지점 (2~3곳 가로 스크롤)  │
│  ┌──────┐ ┌──────┐ ┌──────┐    │
│  │ 대전 │ │ 천안 │ │ 오송 │    │
│  └──────┘ └──────┘ └──────┘    │
└─────────────────────────────────┘

[선택 도시: 대전]

추천 이유: 성심당 등 유명 카페·빵집이...

┌─────── 경로 비교 ───────────────┐
│        나         │   상대방    │
│  대중교통(KTX)    │  자차(일반) │
│  약 50분          │  약 1시간30분│
│  약 47,000원      │  약 24,500원 │
└─────────────────────────────────┘

// isEstimated == true 인 경우 UI:
┌─────── 경로 비교 ───────────────┐
│        나         │   상대방    │
│  대중교통(추정)⚠️  │  자차(일반) │
│  약 80분          │  약 1시간30분│
│  요금 미확인       │  약 18,000원 │
└─────────────────────────────────┘
⚠️ 이 지역은 정확한 대중교통 정보를 제공하기
   어렵습니다. 직접 확인을 권장합니다.

[지도]  ← flutter_map (핀: 출발지2 + 중간지점)

[주변 장소]
  🍽 성심당 본점  ·  맛집  ·  0.3km
  ☕ 카페 봄      ·  카페  ·  0.5km
  ...

  [+ 일정에 추가]  ← 캘린더 연동
```

---

## 6. 네비게이션 연동

Home 또는 Calendar 탭에 진입 버튼 추가:
```dart
// lib/features/home/screens/home_screen.dart 또는 별도 탭
Navigator.push(context, MaterialPageRoute(
  builder: (_) => MidpointSearchScreen(coupleId: coupleId, myUserId: myUserId),
));
```

일정 추가 연동:
```dart
// NearbyPlace 선택 시
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ScheduleAddSheet(
    prefillLocation: place.name,
    prefillLatLng: LatLng(place.lat, place.lng),
  ),
));
```

---

## 7. 환경변수 및 API 키

| 변수명 | 용도 | 관리 위치 |
|--------|------|----------|
| `CLAUDE_API_KEY` | Claude API | Supabase secret |
| `NAVER_CLIENT_ID` | Naver Directions | Supabase secret |
| `NAVER_CLIENT_SECRET` | Naver Directions | Supabase secret |
| `KAKAO_REST_API_KEY` | Kakao (기존) | Supabase secret (기존) |
| `ODSAY_API_KEY` | ODsay (기존) | Supabase secret (기존) |

Naver Cloud Platform 신청 필요:
- Maps — Directions 5 API
- (Geocoding은 Kakao로 대체하여 불필요)

---

## 8. 구현 순서 (Check 항목)

### Phase A: Edge Functions
- [ ] `claude-midpoint` Edge Function 작성 및 배포
- [ ] `supabase secrets set CLAUDE_API_KEY`
- [ ] `naver-directions-proxy` Edge Function 작성 및 배포
- [ ] `supabase secrets set NAVER_CLIENT_ID NAVER_CLIENT_SECRET`
- [ ] `odsay-proxy` whitelist에 `searchPubTransPathT` 추가
- [ ] `kakao-place-search` category 검색 모드 추가

### Phase B: 모델 + 서비스
- [ ] `midpoint_input.dart` 모델 정의
- [ ] `midpoint_result.dart` 모델 정의
- [ ] `naver_directions_service.dart` 구현
- [ ] `midpoint_service.dart` orchestrator 구현 (병렬 호출 포함)
  - Haversine 거리 계산 유틸
  - 대중교통 수단 자동 선택 로직

### Phase C: UI
- [ ] `origin_input_widget.dart` (kakao 자동완성)
- [ ] `transport_selector_widget.dart` (2택 + 자차 세부)
- [ ] `midpoint_search_screen.dart` (3단계 입력 + 로딩)
- [ ] `midpoint_city_card.dart` (도시 카드)
- [ ] `route_comparison_table.dart` (경로 비교표)
- [ ] `midpoint_map_widget.dart` (flutter_map + 핀)
- [ ] `nearby_places_list.dart` (장소 목록 + 일정 추가 버튼)
- [ ] `midpoint_result_screen.dart` (결과 조합)

### Phase D: 연동
- [ ] Home 또는 탭 진입 버튼 추가
- [ ] 일정 추가(ScheduleAddSheet) 연동
