# Design: odsay-proxy (교통편 검색)

## 1. 아키텍처 개요

```
Flutter Web (browser)
    │  HTTP GET /functions/v1/odsay-proxy?endpoint=...&terminalName=...
    ▼
Supabase Edge Function (odsay-proxy)
    │  No CORS issue (same Supabase origin)
    │  Append apiKey from env ODSAY_API_KEY
    ▼
api.odsay.com/v1/api/{endpoint}?...&apiKey=SECRET
```

---

## 2. Supabase Edge Function: odsay-proxy

### 2.1 파일
- `supabase/functions/odsay-proxy/index.ts`

### 2.2 허용 엔드포인트 (화이트리스트)
| 엔드포인트 | 용도 |
|-----------|------|
| `trainTerminals` | 열차역 stationID 조회 |
| `expressBusTerminals` | 고속버스 터미널 stationID 조회 |
| `intercityBusTerminals` | 시외버스 터미널 stationID 조회 |
| `trainServiceTime` | 열차 시간표 조회 |
| `searchInterBusSchedule` | 버스 시간표 조회 |

### 2.3 요청/응답 구조
- **요청**: `GET /functions/v1/odsay-proxy?endpoint={name}&{odsay_params}`
- **응답**: ODsay 원본 응답을 그대로 relay (JSON)
- **CORS**: `Access-Control-Allow-Origin: *`
- **에러**: `{error: {msg: "..."}}` JSON

### 2.4 배포
- `supabase functions deploy odsay-proxy --no-verify-jwt`
- API 키: `supabase secrets set ODSAY_API_KEY=...`

---

## 3. ODsay API 응답 구조

### 3.1 Terminal 엔드포인트 응답 (공통)
```json
{
  "result": [
    {"stationID": 3300128, "stationName": "서울", "haveDestinationTerminals": true, "arrivalTerminals": [...]}
  ]
}
```
> `result`는 **직접 배열 (List)**

### 3.2 trainServiceTime 응답
```json
{
  "result": {
    "count": 2,
    "startStationID": 3300128,
    "endStationID": 3300158,
    "station": [
      {
        "trainClass": "무궁화",
        "trainNo": 1155,
        "departureTime": "07:54",
        "arrivalTime": "10:28",
        "wasteTime": "02:34",
        "runDay": "매일",
        "fare": {"general": "13000", "standing": "11050"}
      }
    ]
  }
}
```
> `result`는 **Map**, 시간표 배열은 `result['station']`

### 3.3 searchInterBusSchedule 응답
```json
{
  "result": {
    "count": 10,
    "stationClass": 4,
    "schedule": [
      {"departureTime": "0600", "wasteTime": 180, "busClass": 2, "fare": 25000}
    ]
  }
}
```
> `result`는 **Map**, 시간표 배열은 `result['schedule']`

---

## 4. Flutter 구현 설계

### 4.1 파일 구조
```
lib/features/transport/
  models/
    transit_result.dart          # TransitResult, TransitType enum
  data/
    station_codes.dart           # 역명 예외 매핑, SRT 전용역, 예매 URL
  services/
    transport_service.dart       # TransportService, TransportSearchResult
  screens/
    transport_search_screen.dart # UI
```

### 4.2 TransitType
```dart
enum TransitType { ktx, srt, itx, mugunghwa, expressbus, bus, intercitybus }
```

### 4.3 TransportService 주요 메서드
| 메서드 | 역할 |
|-------|------|
| `search(from, to, date)` | 열차+버스 통합 검색, `TransportSearchResult` 반환 |
| `_getTrainId(name)` | 열차역 stationID 조회 (캐시) |
| `_getExpBusId(name)` | 고속버스 터미널 stationID 조회 (캐시) |
| `_getIntercityBusId(name)` | 시외버스 터미널 stationID 조회 (캐시) |
| `_searchTerminalId(endpoint, name)` | ODsay 프록시 호출 → stationID 반환 |
| `_fetchTrains(depId, arrId)` | trainServiceTime 호출 → `List<TransitResult>` |
| `_fetchBuses(depId, arrId, stationClass)` | searchInterBusSchedule 호출 → `List<TransitResult>` |
| `_fetchSrtFromSupabase(...)` | Supabase DB에서 SRT 시간표 조회 |
| `_parseTrainItem(raw)` | 열차 응답 아이템 → TransitResult |
| `_parseBusItem(raw)` | 버스 응답 아이템 → TransitResult |
| `_normalizeTime(raw)` | `"0500"` → `"05:00"` 변환 |
| `_parseWasteMinutes(raw)` | int 또는 `"HH:MM"` 형식 → 분 정수 |
| `_matchesRunDay(runDay, date)` | 운행 요일 필터 |

### 4.4 stationID 조회 로직
```
terminal 엔드포인트 응답: result is List
→ result.first['stationID']

역명 변환 우선순위:
1. odsayTrainSearchExceptions[name] (예외 매핑)
2. _deriveTrainSearchTerm(name) (괄호 제거 + '역' 제거)
```

### 4.5 시간 파싱
- `_normalizeTime`: 4자리 `"HHmm"` → `"HH:mm"`, 이미 `":"` 포함 시 그대로
- `_parseWasteMinutes`: `int` → 그대로, `"HH:MM"` → `H*60+M`
- `_calcDurationFromTimeStr`: dep/arr 시간 문자열로 분 계산

### 4.6 요금 파싱 (fare)
- `num` → `.toInt()`
- `List` → `first['general'] ?? first['fare']`
- `Map` → `general` 또는 `fare` 키, `String` 값은 `int.tryParse()`

### 4.7 TransportSearchResult
```dart
class TransportSearchResult {
  List<TransitResult> results;
  bool hasSrtStation;
  String? trainError;
  String? busError;
  // computed: trainResults, busResults, hasError, isEmpty
}
```

### 4.8 인증 헤더
```dart
{
  'Authorization': 'Bearer {accessToken}',
  'apikey': supabaseAnonKey,  // core/supabase_client.dart의 상수
}
```

---

## 5. CI/CD 연동

### 5.1 GitHub Actions (deploy.yml)
- `ODSAY_API_KEY` 시크릿을 `lib/core/api_keys.dart`에 Python 스크립트로 주입
- `odsay-proxy` Edge Function은 별도로 `supabase functions deploy` 수동 또는 별도 워크플로우

---

## 6. 구현 순서 (Check 항목)

- [ ] Supabase Edge Function `odsay-proxy/index.ts` 작성 및 배포
- [ ] `supabase secrets set ODSAY_API_KEY` 설정
- [ ] `TransitType` enum 정의
- [ ] `TransitResult` 모델 정의 (fare, typeLabel, durationLabel, fareLabel, isRailway)
- [ ] `station_codes.dart` 예외 매핑 정의
- [ ] `transport_service.dart` - _proxyBase 상수 (supabaseUrl 활용)
- [ ] `_searchTerminalId()` - result is List 처리
- [ ] `_fetchTrains()` - result['station'] 파싱
- [ ] `_fetchBuses()` - result['schedule'] 파싱
- [ ] `_normalizeTime()`, `_parseWasteMinutes()`, `_matchesRunDay()` 유틸
- [ ] `_fetchSrtFromSupabase()` SRT DB 폴백
- [ ] `transport_search_screen.dart` UI
