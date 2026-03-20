# Design: home-redesign

> Plan 참조: `docs/01-plan/features/home-redesign.plan.md`

---

## 1. 아키텍처 개요

```
home_screen.dart (전면 재작성)
├── _RotatingHeader          (StatefulWidget) ← SharedPreferences 기반 문구 순환
├── _HomeCardPager           (StatefulWidget) ← PageView 4장 + 인디케이터
│   ├── _ScheduleCard        (StatelessWidget) ← Card 1: 오늘/내일 토글
│   ├── _NextMeetingCard     (StatefulWidget)  ← Card 2: 게이지 + last_meeting
│   ├── _TransportCard       (StatelessWidget) ← Card 3: 교통편
│   └── _MidpointCard        (StatelessWidget) ← Card 4: 중간지점
home_service.dart
└── getLastMeeting(coupleId) ← 신규 메서드
theme.dart
└── 파스텔 카드 컬러 4종 추가
pubspec.yaml
└── google_fonts (cormorant_garamond 자동 포함)
```

---

## 2. 데이터 흐름

### 2.1 HomeService 신규 메서드

```dart
/// 마지막 만남 날짜 조회 (category: 데이트 또는 여행, date < today)
Future<DateTime?> getLastMeeting(String coupleId) async {
  final todayStr = DateTime.now().toIso8601String().split('T')[0];
  final result = await supabase
      .from('schedules')
      .select('date')
      .eq('couple_id', coupleId)
      .inFilter('category', ['데이트', '여행'])
      .lt('date', todayStr)
      .order('date', ascending: false)
      .limit(1)
      .maybeSingle();

  if (result == null) return null;
  return DateTime.parse(result['date'] as String);
}
```

### 2.2 getHomeSummary 업데이트

기존 반환값에 `last_meeting` 추가:
```dart
return {
  'd_days': dDays,
  'today_schedules': todaySchedules,
  'tomorrow_schedules': tomorrowSchedules,
  'next_date': nextDate,
  'last_meeting': lastMeeting,   // DateTime? 추가
};
```

### 2.3 HomeScreen 상태값 추가

```dart
DateTime? get _lastMeeting => _data['last_meeting'] as DateTime?;
```

---

## 3. 컴포넌트 상세 설계

### 3.1 _RotatingHeader

**책임**: 방문할 때마다 문구 인덱스 +1, SharedPreferences 저장

```dart
class _RotatingHeader extends StatefulWidget {
  final int dDays;           // D+day 숫자
  final String? nickname;    // "안녕, [닉네임]" 서브텍스트용
}
```

**문구 배열:**
```dart
static const _phrases = [
  (prefix: '',            suffix: ' Days of Love'),
  (prefix: 'Day ',        suffix: ' with You'),
  (prefix: 'Together for ', suffix: ' Days'),
  (prefix: 'Our ',        suffix: 'th Page'),
  (prefix: '',            suffix: ' Days of Us'),
  (prefix: 'A Journey of ', suffix: ' Days'),
  (prefix: '',            suffix: ' & Still Counting'),
];
```

**렌더링 구조 (RichText):**
```
안녕, 민지  ← Noto Sans KR, 14px, textSecondary

[prefix] [N] [suffix]
         ↑
         Cormorant Garamond Bold, 68px, textPrimary
         prefix/suffix: Cormorant Garamond Light, 22px, textSecondary
```

**예시:**
- `A Journey of` `365` `Days`
- `Our` `100` `th Page`

**SharedPreferences 키**: `home_phrase_index` (int, 0~6 순환)
- `initState`에서 현재 인덱스 로드 후 +1 저장

---

### 3.2 _HomeCardPager

**책임**: PageView 컨테이너 + 하단 dot 인디케이터

```dart
class _HomeCardPager extends StatefulWidget {
  final Map<String, List<Schedule>>? todaySchedules;
  final Map<String, List<Schedule>>? tomorrowSchedules;
  final Map<String, dynamic>? nextDate;
  final DateTime? lastMeeting;
  final String? partnerNickname;
  final CoupleProfile? profile;
}
```

**레이아웃:**
```dart
Column(children: [
  SizedBox(
    height: MediaQuery.of(context).size.height * 0.40,  // 화면 40%
    child: PageView(
      controller: _pageController,
      children: [card1, card2, card3, card4],
    ),
  ),
  SizedBox(height: 12),
  _DotIndicator(count: 4, current: _currentPage),
])
```

**_DotIndicator**: 4개 dot, 활성=accent(6px), 비활성=border(6px)

---

### 3.3 Card 1 - _ScheduleCard

**컬러**: `Colors.white` 배경, border: `AppTheme.border`

**레이아웃:**
```
┌─────────────────────────────────────┐
│  [오늘]  [내일]   ← ToggleButtons    │  12px top
│─────────────────────────────────────│  divider
│  나              파트너              │
│  label(10px)     label(10px)        │
│  ● 출근 08:00    ● 휴무             │  11px 항목
│  ● 저녁 약속                        │
│                                     │
│  💕 같이 쉬는 날이에요! (조건부)      │  양쪽 휴무 시
└─────────────────────────────────────┘
```

**토글 구현**: `_isToday` bool 상태, 기본값 `true`
- 탭 시 setState로 토글
- 활성 탭: `AppTheme.primary` 배경, 흰 텍스트
- 비활성 탭: 투명 배경, `AppTheme.textTertiary`

**2컬럼 레이아웃**: `Row(children: [Expanded(나), Expanded(파트너)])`

**양쪽 휴무 감지:**
```dart
final bothOff = mySchedules.any((s) => s.category == '휴무') &&
                partnerSchedules.any((s) => s.category == '휴무');
```

---

### 3.4 Card 2 - _NextMeetingCard

**컬러**: `AppTheme.cardPastelPeach` (신규)

**게이지 진행률 계산:**
```dart
double _calcProgress(DateTime? lastMeeting, int daysUntil) {
  if (lastMeeting != null) {
    final today = DateTime.now();
    final totalDays = today.difference(lastMeeting).inDays + daysUntil;
    if (totalDays <= 0) return 1.0;
    final elapsed = today.difference(lastMeeting).inDays;
    return (elapsed / totalDays).clamp(0.0, 1.0);
  } else {
    // fallback: D-14 기준
    return ((14 - daysUntil) / 14).clamp(0.0, 1.0);
  }
}
```

**게이지 위젯:**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: LinearProgressIndicator(
    value: progress,
    backgroundColor: Colors.white.withValues(alpha: 0.4),
    valueColor: AlwaysStoppedAnimation(
      daysUntil == 0 ? AppTheme.accent : AppTheme.primary,
    ),
    minHeight: 8,
  ),
)
```

**하단 문구 로직:**
```dart
String _buildMeetingMessage(DateTime? lastMeeting, int daysUntil) {
  if (daysUntil == 0) return '오늘 드디어 만나는 날이에요 💕';
  if (lastMeeting == null) return '곧 만나요, 설레는 중이에요';
  final daysSince = DateTime.now().difference(lastMeeting).inDays;
  if (daysSince == 0) return '오늘 막 헤어졌어요';
  if (daysSince == 1) return '벌써 하루가 지났어요';
  return '보고 싶은 지 ${daysSince}일째예요';
}
```

**D-0 당일 특수 처리:**
- 게이지: 100% + `AppTheme.accent` 색상
- 배경: `AppTheme.accentLight` → 더 밝게
- 문구: "오늘 드디어 만나는 날이에요 💕"

**레이아웃:**
```
┌─────────────────────────────────────┐
│  다음 만남                           │  12px Noto, textSecondary
│                                     │
│  3월 28일 토요일                      │  20px Cormorant, textPrimary
│                                  D-3│  accent, 24px bold
│                                     │
│  ████████████████████░░░░  ← 게이지  │  8px 높이
│                                     │
│  보고 싶은 지 11일째예요               │  13px Noto, textSecondary
└─────────────────────────────────────┘
```

---

### 3.5 Card 3 - _TransportCard

**컬러**: `AppTheme.cardPastelMint` (신규)

**헤더**: "가는 길도 설레어" (18px Cormorant Bold)
**서브**: "지금 출발하면 언제 도착할까요" (12px Noto)

**레이아웃:**
```
┌─────────────────────────────────────┐
│  🚇 가는 길도 설레어                  │
│  지금 출발하면 언제 도착할까요         │
│                                     │
│  [내역] ─────────────→ [파트너역]    │  역 아이콘 + 화살표
│   (없으면 "역 정보 설정하기" 표시)    │
│                                     │
│              [교통편 확인하기 →]      │  우측 정렬 버튼
└─────────────────────────────────────┘
```

**교통 정보 없을 때**: "역 정보를 설정하면\n교통편을 바로 확인해요"
**탭 영역**: 카드 전체 GestureDetector → TransportSearchScreen

---

### 3.6 Card 4 - _MidpointCard

**컬러**: `AppTheme.cardPastelLavender` (신규)

**헤더**: "반반 거리, 완벽한 약속장소" (18px Cormorant Bold)
**서브**: "서로의 중간, 딱 공평한 만남의 중심점" (12px Noto)

**레이아웃:**
```
┌─────────────────────────────────────┐
│  📍 반반 거리, 완벽한 약속장소        │
│  서로의 중간, 딱 공평한 만남의 중심점  │
│                                     │
│  [●]────────────────────[●]         │  두 점 사이 라인
│  나                     파트너       │
│                                     │
│              [중간지점 찾아보기 →]    │  우측 정렬 버튼
└─────────────────────────────────────┘
```

**탭 영역**: 카드 전체 GestureDetector → MidpointSearchScreen

---

## 4. 테마 업데이트 (theme.dart)

추가할 파스텔 컬러 4종:

```dart
// ── Home Card Pastels ──────────────────────────────────
static const Color cardPastelPeach    = Color(0xFFFFF0E8); // Card 2: 다음 만남 (피치)
static const Color cardPastelMint     = Color(0xFFE8F5F2); // Card 3: 교통편 (민트)
static const Color cardPastelLavender = Color(0xFFF0ECFF); // Card 4: 중간지점 (라벤더)
// Card 1은 흰색(surface) 사용
```

---

## 5. pubspec.yaml 변경

`google_fonts` 패키지는 이미 설치되어 있으므로 코드에서 바로 사용:

```dart
// 사용 방식
GoogleFonts.cormorantGaramond(
  fontSize: 68,
  fontWeight: FontWeight.w700,
  color: AppTheme.textPrimary,
  height: 1.0,
)
```

별도 assets 추가 불필요 (google_fonts 자동 다운로드).

---

## 6. 구현 순서

| 순서 | 파일 | 작업 |
|------|------|------|
| 1 | `theme.dart` | 파스텔 컬러 3종 추가 |
| 2 | `home_service.dart` | `getLastMeeting()` + `getHomeSummary()` 업데이트 |
| 3 | `home_screen.dart` | `_RotatingHeader` 위젯 구현 |
| 4 | `home_screen.dart` | `_ScheduleCard` (Card 1) 구현 |
| 5 | `home_screen.dart` | `_NextMeetingCard` (Card 2) 구현 |
| 6 | `home_screen.dart` | `_TransportCard`, `_MidpointCard` (Card 3, 4) 구현 |
| 7 | `home_screen.dart` | `_HomeCardPager` + `_DotIndicator` 조립 |
| 8 | `home_screen.dart` | `_buildHomeContent` 전체 교체 |

---

## 7. 삭제 예정 파일 (구현 후)

- `lib/features/home/widgets/dday_widget.dart`
- `lib/features/home/widgets/today_schedule_widget.dart`
- `lib/features/home/widgets/next_date_widget.dart`
- `lib/features/home/widgets/transport_preview_card.dart`

> 단, 다른 화면에서 import 여부 먼저 확인 후 삭제
