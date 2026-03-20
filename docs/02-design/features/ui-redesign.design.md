# UI Redesign Design — 커플듀티 "Deux" 전체 화면 디자인 시스템

> 관련 Plan: `docs/01-plan/features/ui-redesign.plan.md`

---

## 1. 디자인 시스템 (Design Tokens)

### 1.1 컬러 팔레트

```dart
// ── Core ──
static const Color primary         = Color(0xFF1A2A4A); // 딥 네이비
static const Color accent          = Color(0xFFC9A84C); // 소프트 골드
static const Color accentLight     = Color(0xFFF5EDD6); // 골드 연배경
static const Color background      = Color(0xFFF4F5F9); // 블루그레이 BG
static const Color surface         = Color(0xFFFFFFFF); // 카드/시트

// ── Border ──
static const Color border          = Color(0xFFE8EAF0); // subtle

// ── Text ──
static const Color textPrimary     = Color(0xFF1A2A4A); // = primary
static const Color textSecondary   = Color(0xFF6B7280); // 중간
static const Color textTertiary    = Color(0xFFB0B7C3); // 힌트/비활성

// ── Semantic ──
static const Color success         = Color(0xFF38A169);
static const Color error           = Color(0xFFE53E3E);
static const Color warning         = Color(0xFFD97706);
static const Color googleBlue      = Color(0xFF4285F4); // 구글 아이콘 유지
static const Color excelGreen      = Color(0xFF1D6F42); // 엑셀 아이콘 유지

// ── Shadows ──
static const BoxShadow cardShadow = BoxShadow(
  color: Color(0x141A2A4A), // 8% opacity
  blurRadius: 20,
  offset: Offset(0, 4),
);
static const BoxShadow subtleShadow = BoxShadow(
  color: Color(0x0A1A2A4A), // 4% opacity
  blurRadius: 12,
  offset: Offset(0, 2),
);
```

**현재 → 변경 대조**

| 토큰 | 현재 | 변경 후 |
|------|------|---------|
| primary | `#2C2C2C` | `#1A2A4A` |
| accent | `#E8A598` | `#C9A84C` |
| background | `#F9F9F9` | `#F4F5F9` |
| dateBorderColor | `#FF4081` | `#C9A84C` (골드) |
| textSecondary | `#9E9E9E` | `#6B7280` |
| cardStyle | border-only | shadow + no border |

---

### 1.2 타이포그래피

```dart
// Playfair Display: D-day 숫자, 로고, 강조 헤드라인
// Noto Sans KR: 나머지 전체 (현행 유지)
GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.bold)
GoogleFonts.notoSansKr(...)
```

| 역할 | 폰트 | 크기 | 굵기 |
|------|------|------|------|
| 로고/D+숫자 | Playfair Display | 40px | Bold |
| 섹션 헤드 | Noto Sans KR | 20px | w600 |
| AppBar 타이틀 | Noto Sans KR | 17px | w600 |
| Body | Noto Sans KR | 15px | w400 |
| Sub | Noto Sans KR | 13px | w400 |
| Caption/NavLabel | Noto Sans KR | 11px | w500 |

---

### 1.3 컴포넌트 공통 스펙

#### 카드 (모든 섹션 카드)
```dart
// border → shadow 전환
decoration: BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(20),
  boxShadow: [AppTheme.cardShadow],
  // border: 제거
)
```

#### ElevatedButton (Primary)
```dart
backgroundColor: AppTheme.primary,   // Navy
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
```

#### ElevatedButton (Accent CTA)
```dart
// 중간지점 검색 버튼 등 핵심 CTA
backgroundColor: AppTheme.accent,    // Gold
foregroundColor: AppTheme.primary,   // Navy text
```

#### TabBar (일정 자동등록)
```dart
labelColor: AppTheme.primary,
indicatorColor: AppTheme.accent,     // Gold 인디케이터
indicatorWeight: 2.5,
```

#### BottomSheet
```dart
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
)
```

#### FloatingActionButton
```dart
backgroundColor: AppTheme.primary,   // Navy
foregroundColor: Colors.white,
```

---

## 2. 화면별 상세 설계

---

### 2.1 로그인 화면 (`auth/screens/login_screen.dart`)

**변경 전:** "We" + 다크그레이 버튼
**변경 후:**

```
┌──────────────────────────────────┐
│  [72px 상단 여백]                │
│                                  │
│  DEUX                            │  Playfair Display 40px, Gold
│  커플 스케줄을 함께 관리하세요    │  Noto 15px, textSecondary
│                                  │
│  [56px 여백]                     │
│                                  │
│  이메일                          │  label 13px
│  ┌──────────────────────────┐    │
│  │ example@email.com        │    │  border Navy on focus
│  └──────────────────────────┘    │
│                                  │
│  비밀번호                        │
│  ┌──────────────────────────┐    │
│  │ ••••••          [👁]     │    │
│  └──────────────────────────┘    │
│                                  │
│  [36px 여백]                     │
│                                  │
│  ┌──────────────────────────┐    │
│  │         로그인            │    │  Navy ElevatedButton h=52
│  └──────────────────────────┘    │
│                                  │
│  아직 계정 없으신가요? [회원가입] │  textButton Gold
└──────────────────────────────────┘
```

**변경 코드 포인트:**
- `"We"` → `"DEUX"` + `GoogleFonts.playfairDisplay`, `color: AppTheme.accent`
- `letterSpacing: 2.0` 추가 (고급스러운 느낌)
- 배경: `#F4F5F9` (자동 반영)
- 회원가입 TextButton: `color: AppTheme.accent`

---

### 2.2 회원가입 화면 (`auth/screens/signup_screen.dart`)

로그인과 동일한 로고 처리. 추가 변경:
- 상단 "DEUX" 로고 (로그인과 통일)
- 뒤로가기 버튼: textTertiary 색상
- 가입 완료 버튼: Navy ElevatedButton

---

### 2.3 온보딩 화면 (4단계)

**공통 레이아웃:**
```
┌──────────────────────────────────┐
│  ← 뒤로                          │
│                                  │
│  ●●○○  (진행 도트)               │  선택: Gold ●, 미선택: border ○
│                                  │
│  [아이콘 컨테이너]               │  accentLight bg, radius 20, 64px
│  [제목 텍스트]                   │  Noto 22px SemiBold, Navy
│  [설명 텍스트]                   │  Noto 14px, textSecondary
│                                  │
│  [내용 영역 - 단계별]             │
│                                  │
│  ┌──────────────────────────┐    │
│  │        다음 →             │    │  Navy Button (마지막 단계: 시작하기)
│  └──────────────────────────┘    │
└──────────────────────────────────┘
```

**진행 도트 변경:**
```dart
// 현재: 검정 점
// 변경: Gold 활성, border 비활성
Container(
  width: isActive ? 20 : 8,  // 활성 탭 width 확장
  height: 8,
  decoration: BoxDecoration(
    color: isActive ? AppTheme.accent : AppTheme.border,
    borderRadius: BorderRadius.circular(4),
  ),
)
```

**Step1 (닉네임):** 입력 포커스 → Navy border
**Step2 (근무유형):** 선택된 카드 → accentLight bg + Gold border + Gold 체크 아이콘
**Step3 (거리/지역):** 선택된 옵션 → accentLight bg + Gold border
**Step4 (커플코드):** 코드 표시 박스 → accentLight bg + Gold border

---

### 2.4 커플 연결 화면 (`couple/screens/couple_connect_screen.dart`)

```
┌──────────────────────────────────┐
│  ← 커플 연결                      │
│                                  │
│  ┌────────────────────────────┐  │
│  │  내 연결 코드               │  │  shadow card
│  │  ┌──────────────────────┐  │  │
│  │  │  A1B2C3D4            │  │  │  accentLight bg, Gold border
│  │  └──────────────────────┘  │  │
│  │  [복사하기]                 │  │  Outlined + Gold icon
│  └────────────────────────────┘  │
│                                  │
│  ─── 또는 ───                    │  textTertiary
│                                  │
│  ┌────────────────────────────┐  │
│  │  파트너 코드 입력           │  │  shadow card
│  │  ┌──────────────────────┐  │  │
│  │  │ 코드를 입력하세요     │  │  │
│  │  └──────────────────────┘  │  │
│  │  [연결하기]                 │  │  Navy Button
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

---

### 2.5 홈 화면 (`home/screens/home_screen.dart` + widgets)

**AppBar:**
```
우리의 이야기          [🔔] [↺]
3월 20일 (금) · 봄꽃 축제          ← 공휴일 있을 때
```
- 새로고침 아이콘 → 오른쪽 유지

**D-day 카드 (`dday_widget.dart`):**
```
┌──────────────────────────────────┐
│ ✦                               │  Gold 별 아이콘, 우상단
│                                  │
│   D + 3 6 5                      │  Playfair Display 40px Bold, White
│   2024.03.20 시작       ♡ 지민   │  12px White/70% + Gold 닉네임
└──────────────────────────────────┘
```
```dart
gradient: LinearGradient(
  colors: [Color(0xFF1A2A4A), Color(0xFF243656)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(20),
boxShadow: [AppTheme.cardShadow],
```

**다음 데이트 카드 (`next_date_widget.dart`):**
```
다가오는 데이트                >
┌──────────────────────────────────┐
│  🗓  3월 25일 토요일              │
│     홍대입구 카페 거리 데이트     │
│     ┌────┐ D-5  ·  오후 2:00    │  Gold 뱃지
│     └────┘                       │
└──────────────────────────────────┘
```
- D-N 뱃지: `accentLight` bg + Gold text, `border-radius: pill`
- shadow card, radius 20

**중간지점 배너 (`_MidpointBanner`):**
```
┌──────────────────────────────────┐
│ ┌────┐                           │
│ │ 📍 │  중간지점 찾기         >  │  accentLight bg
│ └────┘  두 사람이 공평하게 만날  │
│         수 있는 곳 추천          │
└──────────────────────────────────┘
```
- 아이콘 컨테이너: `accent.withOpacity(0.15)` 원형
- 배경: `accentLight (#F5EDD6)`
- border: `accent.withOpacity(0.4)`

**오늘/내일 일정 (`today_schedule_widget.dart`):**
```
오늘의 일정 (2)                   ← 섹션 헤더 16px SemiBold, Navy
┌──────────────────────────────────┐
│  ● 저녁 영화 관람       오후 7시│  ● = 일정 색상
│  ─────────────────────────────── │  Divider
│  ● 주말 여행 계획          종일  │
└──────────────────────────────────┘
```
- 일정 없을 때: "오늘은 일정이 없어요 ✦" (textTertiary)

**교통 카드 (`transport_preview_card.dart`):**
- shadow card, radius 20
- 출발역 → 도착역 화살표: Gold 색상

---

### 2.6 캘린더 화면 (`calendar/screens/calendar_screen.dart`)

**AppBar 변경:**
```dart
// 현재 AppBar actions: 4개 아이콘 (지도, 구글, OCR, 삭제)
// 변경: 아이콘 색상만 통일

// 지도 아이콘: AppTheme.primary (Navy) — 현행 유지
// 구글 캘린더: googleBlue (Color(0xFF4285F4)) — 현행 유지
// OCR 아이콘: warning (Color(0xFFD97706)) — 현행 orangeAccent 대체
// 삭제 아이콘: error (Color(0xFFE53E3E)) — 현행 redAccent 대체
```

**달력 셀 (`_CalendarCell`):**
```dart
// 선택된 날짜
numDecoration = BoxDecoration(
  color: AppTheme.primary,   // Navy 원 — 현행 유지
  shape: BoxShape.circle,
);

// 오늘 날짜
numDecoration = BoxDecoration(
  color: AppTheme.primary.withOpacity(0.15), // Navy 연배경
  shape: BoxShape.circle,
);

// 기념일 이벤트 바 색상
// 현재: Color(0xFFFF4081) 핫핑크 → 변경: AppTheme.accent Gold
color: s.isAnniversary ? AppTheme.accent : getColor(s),

// 커플 일정 하트 뱃지
// 현재: Color(0xFFFF4081) → 변경: AppTheme.accent
color: AppTheme.accent,

// 오버플로 텍스트 (+N)
color: AppTheme.textTertiary,  // 현재 textSecondary → 더 연하게
```

**FAB (일정 추가):**
```dart
backgroundColor: AppTheme.primary,   // 현행 유지 (자동 반영)
```

**DayDetailSheet (날짜 상세):**
```
┌────────────────────────────────┐  radius 28 top
│ ───                            │  핸들 바
│ 3월 25일 토요일    [+ 추가]    │  제목 + Gold 추가 버튼
│ ─────────────────────────────  │
│ [나의 일정]                    │  섹션 헤더
│ ● 저녁 영화        오후 7시    │
│ ─────────────────────────────  │
│ [지민의 일정]                  │
│ ● 근무 (데이)      08:00-17:00 │
└────────────────────────────────┘
```

**ScheduleAddSheet (일정 추가):**
```
┌────────────────────────────────┐
│ ─── 일정 추가                  │
│ 제목 [_____________]           │
│ 날짜 [2026-03-25]              │
│ 카테고리 ○근무 ○데이트 ○여행  │  선택: Navy bg, White text
│ 색상 [● ● ● ● ...]            │
│ [저장하기]                     │  Navy Button
└────────────────────────────────┘
```
- 카테고리 선택 칩: selected → `primary` bg + white text
- 색상 선택 원: selected → Gold 테두리 2px

---

### 2.7 일정 자동등록 화면 (`schedule/screens/auto_registration_screen.dart`)

**TabBar 변경:**
```dart
// 현재: indicatorColor = AppTheme.primary (검정)
// 변경:
labelColor: AppTheme.primary,          // Navy 텍스트
indicatorColor: AppTheme.accent,       // Gold 언더라인
indicatorWeight: 2.5,
unselectedLabelColor: AppTheme.textTertiary,
```

**_buildTabHeader 변경:**
```dart
// 현재: iconColor.withOpacity(0.06) 배경
// 변경: iconColor는 유지, 배경만 약간 조정 (현행과 유사)
// 탭 1 (OCR): primary → Navy 아이콘 유지
// 탭 2 (Google): googleBlue 유지 (브랜드 컬러)
// 탭 3 (Excel): excelGreen 유지 (브랜드 컬러)
```

**_buildActionCard 변경:**
```dart
// 현재: border + 약한 shadow
// 변경: shadow card (border 제거)
boxShadow: [AppTheme.cardShadow],
// border: Border.all 제거
```

**_buildTipBox 변경:**
```dart
// 현재: border + white
// 변경: accentLight bg + Gold border
color: AppTheme.accentLight,
border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
// 아이콘: Gold
Icon(Icons.lightbulb_outline, color: AppTheme.accent),
```

**배지 색상:**
```dart
// 탭 1 "AI 분석": primary → Navy
// 탭 2 "정확도 100%": success Green 유지
// 탭 3 "Premium": accent Gold (현행 amber와 유사, 통일)
badgeColor: AppTheme.accent,
```

---

### 2.8 OCR 리뷰 화면 (`schedule/screens/ocr_review_screen.dart`)

```
┌──────────────────────────────────┐
│ ← OCR 결과 검토                   │
│ [스텝 인디케이터] ────────────── │  Gold 진행
│                                  │
│ 인식된 일정 (15개)               │  Navy h2
│                                  │
│ ┌──────────────────────────────┐ │
│ │ ☑  3/1 (토)  근무 (데이)    │ │  체크박스: Navy
│ │    08:00 ~ 17:00             │ │
│ └──────────────────────────────┘ │  shadow card
│ ...                               │
│                                  │
│ [15개 일정 저장하기]              │  Navy Button
└──────────────────────────────────┘
```
- 체크박스 active: `primary` (Navy)
- 체크된 아이템: 배경 `primary.withOpacity(0.05)`
- 오류/수정 필요 아이템: `error.withOpacity(0.05)` 배경

---

### 2.9 중간지점 검색 화면 (`midpoint/screens/midpoint_search_screen.dart`)

**_SectionCard 변경:**
```dart
// 현재: border
// 변경: shadow card
decoration: BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [AppTheme.cardShadow],
  // border 제거
),
```

**_ThemeButton 변경:**
```dart
// 현재: selected → accent.withOpacity(0.12) bg + accent border
// 변경: selected → accentLight bg + accent border + Gold text
color: selected ? AppTheme.surface : AppTheme.background,
// selected bg는 accentLight 사용
color: selected ? AppTheme.accentLight : AppTheme.background,
border: Border.all(
  color: selected ? AppTheme.accent : AppTheme.border,
  width: selected ? 1.5 : 1,
),
// 텍스트: selected → accent Gold, unselected → textSecondary
```

**검색 버튼:**
```dart
// 현재: accent (살구핑크 계열) → 변경: accent (Gold)
// theme.dart 변경으로 자동 반영됨
backgroundColor: AppTheme.accent,   // Gold 유지
foregroundColor: AppTheme.primary,  // Navy text (변경)
```

---

### 2.10 중간지점 결과 화면 (`midpoint/screens/midpoint_result_screen.dart`)

**도시 카드 (`midpoint_city_card.dart`):**
```dart
// 현재: border
// 변경: shadow card
decoration: BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(20),
  boxShadow: [AppTheme.cardShadow],
),
```

**추천 탭 칩:**
```dart
// 선택된 기준 탭 (균형/내 기준/상대방 기준)
// selected: primary bg + white text
// unselected: border + textSecondary
```

**데이트 명소 (`date_spots_widget.dart`):**
```dart
// 명소 카드 배경
color: AppTheme.accentLight,  // Gold 연배경
// 아이콘: Gold
// border: accent.withOpacity(0.25)
```

**지도 마커 (`midpoint_map_widget.dart`):**
```
출발지 마커: Navy 핀
추천 중간지점: Gold 별 ✦
주변 장소: Navy 원형 핀
```

**이동 시간 비교 테이블 (`route_comparison_table.dart`):**
```
나 vs 상대방 행
균형 차이: success Green (차이 적음) / warning Orange (차이 많음)
```

---

### 2.11 교통 검색 화면 (`transport/screens/transport_search_screen.dart`)

```
┌──────────────────────────────────┐
│ ← 교통편 검색                     │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 출발역  [강남역          ↕] │ │  shadow card
│ │ 도착역  [홍대입구역       ] │ │
│ └──────────────────────────────┘ │
│                                  │
│ [검색]                            │  Navy Button
│                                  │
│ ── 결과 ──                       │
│ ┌──────────────────────────────┐ │
│ │ 지하철 2호선    35분    ✦    │ │  Gold 추천 별
│ │ 환승 없음       1,450원      │ │  shadow card
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ 버스 + 지하철  42분          │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```
- 결과 카드: shadow card, radius 16
- 최적 경로 뱃지: `accentLight` bg + Gold text "추천"
- 소요시간 강조: Navy SemiBold 18px

---

### 2.12 알림 화면 (`notifications/screens/notification_history_screen.dart`)

```
┌──────────────────────────────────┐
│ 알림                    [모두읽기]│
│                                  │
│ ┌──────────────────────────────┐ │  읽지 않은 알림 (accentLight bg)
│ │ 🗓 [NEW] 내일 데이트가 있어요│ │
│ │   지민과 홍대 카페 데이트    │ │
│ │   방금 전                    │ │  textTertiary
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │  읽은 알림 (white bg)
│ │ 💑 파트너가 일정을 추가했어요│ │
│ │   3월 25일 영화 관람         │ │
│ │   2시간 전                   │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```
- **읽지 않은 알림:** `accentLight` 배경
- **읽은 알림:** `surface` 배경
- **알림 아이콘 컨테이너:** 42px 원형, type별 색상 (데이트: Gold, 시스템: Navy, 경고: warning)
- **시간 텍스트:** `textTertiary`
- **[NEW] 뱃지:** Gold bg, Navy text

---

### 2.13 알림 설정 화면 (`notifications/screens/notification_settings_screen.dart`)

```
┌──────────────────────────────────┐
│ ← 알림 설정                       │
│                                  │
│ ┌──────────────────────────────┐ │  shadow card
│ │ 데이트 알림                  │ │  섹션 헤더
│ │ ─────────────────────────── │ │
│ │ 데이트 당일 알림    [────●] │ │  Switch: Navy/Gold
│ │ 하루 전 알림       [────●] │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 파트너 일정 알림             │ │
│ │ 일정 추가 시 알림  [●────] │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```
- Switch `activeColor`: `AppTheme.accent` (Gold)
- Switch `activeTrackColor`: `accentLight`
- 설정 카드: shadow card (border 제거)

---

### 2.14 설정 화면 (`settings/screens/settings_screen.dart`)

**섹션 카드 변경:**
```dart
// 모든 Container (커플정보, 프로필, 근무, 거리, 앱설정)
// 현재: border
// 변경: shadow card
BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [AppTheme.subtleShadow],  // cardShadow보다 약하게
)
```

**커플 정보 카드:**
```
┌──────────────────────────────────┐
│ ♡ 민준  &  지민                  │  Gold ♡ 아이콘
│ 📅 연애 시작일: 2024.03.20 [✏]  │  Navy 연필 아이콘
│ ─────────────────────────────── │
│ 💔 헤어지기               >     │  error Red 텍스트
└──────────────────────────────────┘
```

**ListTile 변경:**
```dart
// 아이콘 color: AppTheme.primary (Navy) — 일반 항목
// 파트너 관련: AppTheme.accent (Gold)
// 위험 항목 (헤어지기): error Red — 현행 유지
```

**근무유형 바텀시트 옵션:**
```dart
// 선택된 항목
color: AppTheme.accentLight,           // accentLight bg
border: Border.all(color: AppTheme.accent, width: 1.5),
// 체크 아이콘: Gold
Icon(Icons.check_circle_rounded, color: AppTheme.accent),
// 텍스트: Navy
```

**거리유형 바텀시트 옵션:** 동일 패턴 적용

**로그아웃 버튼:**
```dart
// 현재: redAccent border + redAccent text
// 변경: 유지 (위험 액션이므로 red 유지)
```

**회원탈퇴 텍스트버튼:**
```dart
// 현재: Colors.grey + underline
// 변경: textTertiary + underline (통일)
```

---

### 2.15 지도 화면 (`calendar/screens/date_map_screen.dart`)

```
┌──────────────────────────────────┐
│ ← 우리의 데이트 지도              │
│                                  │
│ [지도 영역 전체]                  │
│   Navy 마커: 내 일정             │
│   Gold 마커: 파트너 일정         │
│   Silver 마커: 공유 일정         │
│                                  │
│ ── 하단 시트 ────────────────── │  radius 28 top
│ ● 홍대 카페거리 (데이트)         │
│ ● 강남 영화관 (여행)             │
└──────────────────────────────────┘
```
- 내 일정 마커: Navy `#1A2A4A`
- 파트너 일정 마커: Gold `#C9A84C`
- 클러스터 원: Navy bg + white count

---

## 3. Dialog/AlertDialog 전체 통일

**기본 Dialog 스타일:**
```dart
AlertDialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  // 제목: 17px SemiBold, Navy
  // 내용: 14px, textSecondary, height 1.5
  // 취소 버튼: TextButton, textSecondary
  // 확인 버튼: ElevatedButton, Navy (위험: Red 유지)
)
```

**위험 경고 박스 (헤어지기/탈퇴):**
```dart
// 현재: Colors.red.withOpacity(0.08)
// 변경: error.withOpacity(0.08) — 동일 색상, 상수 사용
color: AppTheme.error.withOpacity(0.08),
border: Border.all(color: AppTheme.error.withOpacity(0.3)),
```

---

## 4. 공통 패턴: 섹션 헤더

모든 화면의 섹션 제목 일관성:
```dart
Widget _buildSectionHeader(String title, {VoidCallback? onMore}) {
  return Row(children: [
    Text(title, style: TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary,
    )),
    Spacer(),
    if (onMore != null)
      GestureDetector(
        onTap: onMore,
        child: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textTertiary),
      ),
  ]);
}
```

---

## 5. 구현 순서 (P0 → P3)

| 순서 | 파일 | 변경 내용 | 영향범위 |
|------|------|----------|---------|
| **P0** | `lib/core/theme.dart` | 색상/타이포/컴포넌트 전체 | 앱 전체 80% 자동 |
| **P0** | `lib/features/auth/screens/login_screen.dart` | DEUX 로고 + Playfair | 로그인 |
| **P0** | `lib/features/auth/screens/signup_screen.dart` | DEUX 로고 | 회원가입 |
| **P0** | `lib/main.dart` | BottomNav 색상 통일 | 전역 네비 |
| **P1** | `lib/features/home/widgets/dday_widget.dart` | Navy gradient + Playfair | 홈 핵심 |
| **P1** | `lib/features/home/widgets/next_date_widget.dart` | Gold 뱃지 + shadow | 홈 |
| **P1** | `lib/features/home/widgets/today_schedule_widget.dart` | shadow card | 홈 |
| **P1** | `lib/features/home/screens/home_screen.dart` | _MidpointBanner + 섹션헤더 | 홈 |
| **P1** | `lib/features/home/widgets/transport_preview_card.dart` | shadow card | 홈 |
| **P2** | `lib/features/calendar/screens/calendar_screen.dart` | 기념일→Gold, AppBar 아이콘 | 캘린더 |
| **P2** | `lib/features/calendar/widgets/day_detail_sheet.dart` | 시트 스타일 | 캘린더 |
| **P2** | `lib/features/calendar/widgets/schedule_add_sheet.dart` | 카테고리 칩 + 색상선택 | 캘린더 |
| **P2** | `lib/features/schedule/screens/auto_registration_screen.dart` | TabBar indicator + 카드 | 자동등록 |
| **P2** | `lib/features/onboarding/screens/*.dart` | 진행도트 + 카드 | 온보딩 |
| **P2** | `lib/features/midpoint/screens/midpoint_search_screen.dart` | shadow card + Gold CTA | 중간지점 |
| **P2** | `lib/features/midpoint/widgets/*.dart` | shadow card + Gold 명소 | 중간지점 |
| **P3** | `lib/features/transport/screens/transport_search_screen.dart` | shadow card + Gold 추천 | 교통 |
| **P3** | `lib/features/settings/screens/settings_screen.dart` | shadow card + accentLight 선택 | 설정 |
| **P3** | `lib/features/notifications/screens/*.dart` | accentLight 미읽음 + Gold 알림 | 알림 |
| **P3** | `lib/features/couple/screens/couple_connect_screen.dart` | accentLight 코드박스 | 커플연결 |

---

## 6. theme.dart 신규 추가 상수

```dart
// 기존 없는 항목 추가
static const Color accentLight     = Color(0xFFF5EDD6);
static const Color textTertiary    = Color(0xFFB0B7C3);
static const Color success         = Color(0xFF38A169);
static const Color error           = Color(0xFFE53E3E);
static const Color warning         = Color(0xFFD97706);

static const BoxShadow cardShadow = BoxShadow(
  color: Color(0x141A2A4A),
  blurRadius: 20,
  offset: Offset(0, 4),
);
static const BoxShadow subtleShadow = BoxShadow(
  color: Color(0x0A1A2A4A),
  blurRadius: 12,
  offset: Offset(0, 2),
);
```

---

## 7. theme.dart 자동 반영 항목 (코드 수정 불필요)

theme.dart 교체만으로 자동 반영되는 항목:
- `ElevatedButton` 전체 (backgroundColor → Navy)
- `OutlinedButton` 전체
- `InputDecoration` 전체 (focus border → Navy)
- `AppBar` 전체 (title, icons → Navy)
- `BottomNavigationBar` (selected → Navy)
- `Card` 스타일 (자동 반영되나 shadow는 직접 수정 필요)
- `CircularProgressIndicator` (colorScheme.primary → Navy)
- `LinearProgressIndicator`
- `CheckBox`, `Switch` (theme 설정 시)
- `TabBar` (labelColor, indicatorColor 설정 필요)
