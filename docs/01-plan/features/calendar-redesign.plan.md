# calendar-redesign Plan

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | calendar-redesign |
| 작성일 | 2026-03-19 |
| 단계 | Plan |

### Value Delivered

| 관점 | 내용 |
|------|------|
| Problem | 나/파트너/우리 탭이 분리되어 있어 전체 일정을 한눈에 보기 어렵고, 도트 표시로는 일정 내용을 알 수 없으며, 일정 추가 폼이 소유자 구분 없이 단순함 |
| Solution | 통합 달력 + 가로 바(제목 포함) + 바텀시트 상세 + 소유자 선택(나/파트너/우리) 일정 추가 폼으로 완전 재설계 |
| Function UX Effect | 달력에서 당일 모든 일정을 즉시 파악, 누구 일정인지 한눈에 구분, 날짜 탭 시 자연스러운 바텀시트로 세부 확인 |
| Core Value | 커플이 서로의 일정을 실시간으로 공유·파악하는 핵심 가치를 극대화한 통합 공유 달력 |

---

## 1. 기능 개요

### 1.1 변경 범위

기존 달력의 세 가지 핵심 문제를 해결하는 전면 재설계:

1. **달력 셀 표시**: 도트 → 가로 바 (제목 포함, 넘치면 말줄임)
2. **날짜 상세**: 전체 화면 이동 → 아래서 위로 올라오는 바텀시트
3. **일정 추가 폼**: 소유자 선택(나/파트너/우리) + 하루종일 스크롤 토글 추가
4. **탭 구조 제거**: 나/파트너/우리 필터 탭 → 통합 달력 하나로 통합
5. **정렬 규칙**: 날짜 내 일정 순서 → 우리 → 내 → 파트너

### 1.2 제거되는 기존 기능 (코드/데이터 정리)

| 제거 대상 | 이유 |
|-----------|------|
| `ScheduleFilter` enum (mine/partner/both) | 통합 달력으로 불필요 |
| `_buildFilterBar()` 위젯 | 필터 UI 제거 |
| `_buildLegend()` 위젯 | 도트 범례 → 바로 대체 |
| `ScheduleService.getMonthSchedules` 필터 파라미터 | 항상 전체 조회 |
| 달력 그리드/리스트 전환 버튼 (`_showCalendarGrid`) | 단일 뷰로 통합 |

---

## 2. 상세 요구사항

### 2.1 달력 셀 (CalendarCell)

```
[ 19 ]
[──yu──────]    ← 우리 일정 (상단)
[──yugg────]    ← 내 일정
[──...─────]    ← 파트너 일정
[ +2 더보기 ]  ← 3개 초과 시 표시
```

- 바 높이: 16~18px, 글자 11~12px, 넘치면 말줄임(...)
- **최대 3개** 바 표시 후 "+N 더보기" 텍스트
- 바 색상: 일정의 `colorHex` 또는 카테고리 기본 색
- 날짜 숫자 아래 바로 시작 (도트 범례 없음)
- 셀 높이: 고정하지 않고 바 개수에 따라 자연스럽게 조정

### 2.2 날짜 상세 (DayDetailSheet) — 바텀시트

이미지 2번 참고:

```
┌──────────────────────────────────┐
│ ───── (드래그 핸들)               │
│ 3월 19일 (목)                    │
│ [일정] [투두] [디데이]            │  ← 탭 (기존 유지 또는 일정만)
│ ──────────────────────────────── │
│ [나] yu          오전 1:00~2:00  ⋯│
│ [나] yugg        오전 1:00~2:00  ⋯│
│                                  │
└──────────────────────────────────┘
```

- `showModalBottomSheet` + `DraggableScrollableSheet` 사용
- 초기 높이: 화면의 50%, 최대 85%
- 일정 카드: 좌측 소유자 뱃지(나/파/우) + 제목 + 시간 + `⋯` 메뉴
- 정렬: **우리 → 나 → 파트너** 순서
- `⋯` 탭: 수정/삭제 액션시트

### 2.3 일정 추가 폼 (ScheduleAddSheet)

기존 Dialog → **바텀시트** 형태로 변경, 필드 순서:

| 순서 | 필드 | 구현 방식 |
|------|------|-----------|
| 1 | 제목 * | TextField |
| 2 | 누구 일정? | SegmentedButton: 나 / 파트너 / 우리 |
| 3 | 하루종일 | Switch + 시간 영역 show/hide |
| 4 | 시작 날짜·시간 | DatePicker + CupertinoTimerPicker (스크롤) |
| 5 | 종료 날짜·시간 | DatePicker + CupertinoTimerPicker (스크롤) |
| 6 | 색상 | 색상 팔레트 (기존 19색 유지) |
| 7 | 종류 | Chip 선택: 근무/약속/여행/데이트/기타 |
| 8 | 장소 (선택) | TextField |
| 9 | 메모 (선택) | TextField multiline |

**하루종일 선택 시**: 시작·종료 시간 영역 숨김, `startTime = null, endTime = null`

### 2.4 일정 소유자 (owner_type) 필드

Supabase `schedules` 테이블에 컬럼 추가:

```sql
ALTER TABLE schedules ADD COLUMN owner_type TEXT DEFAULT 'me'
  CHECK (owner_type IN ('me', 'partner', 'couple'));
```

| owner_type | 의미 | 표시 뱃지 |
|------------|------|-----------|
| `couple` | 우리 일정 | `우` 또는 `♡` |
| `me` | 내 일정 | `나` |
| `partner` | 파트너 일정 | `파` |

**마이그레이션**: 기존 `isDate=true` → `owner_type='couple'`, 나머지 → `owner_type='me'`

**정렬 로직**:
```dart
int _ownerOrder(Schedule s, String myId) {
  if (s.ownerType == 'couple') return 0;
  if (s.userId == myId && s.ownerType == 'me') return 1;
  return 2; // partner
}
```

### 2.5 통합 달력 쿼리 (필터 제거)

```dart
// 기존: filter 파라미터로 mine/partner/both 분기
// 변경: 항상 coupleId 기준 전체 조회
supabase.from('schedules')
  .select()
  .eq('couple_id', coupleId)
  .gte('date', firstDay)
  .lte('date', lastDay)
```

---

## 3. UX 개선 제안 (유저 관점 분석)

### 3.1 예상 불편점 및 해결 방안

| 불편점 | 해결 방안 |
|--------|----------|
| 일정이 많은 날 셀이 너무 길어짐 | 최대 3개 바 + "+N 더보기", 클릭 시 바텀시트로 확인 |
| 누구 일정인지 바 색상만으로 구분 어려움 | 바텀시트의 소유자 뱃지(나/파/우)로 명확히 표시, 바에는 색상 유지 |
| 파트너 일정을 내가 등록하는 것이 어색 | "파트너" 선택 시 설명 문구: "파트너 대신 등록하는 일정이에요" |
| 하루종일 이벤트와 시간 이벤트 구분 | 하루종일=시간 없음, 시간 있는 일정은 바에 시간 미표시(제목만) |
| 바텀시트 닫을 때 실수로 닫힘 | 드래그 핸들 명시, 입력 중에는 뒤로가기 확인 다이얼로그 |
| 달력 셀 바 클릭 → 해당 일정 바로 열기 | 바 탭 → 해당 일정 상세로 바로 이동 (바텀시트 → 상세) |

### 3.2 커플 공유 달력으로서 효과적인 설계 (조언)

**색상 전략**: 소유자별 색상 계열을 권장색으로 제안
- 우리(couple): 분홍/코랄 계열
- 나(me): 파랑/민트 계열
- 파트너(partner): 보라/라벤더 계열

사용자가 직접 색상을 고르더라도 팔레트를 3섹션으로 나누어 제안하면 자연스럽게 구분됨

**바텀시트 탭**: 일정(schedules) 외에 투두, 디데이도 같은 패턴으로 통합하면 UX 일관성 ↑

**"우리" 이벤트 강조**: couple 타입 이벤트를 분홍 하트 아이콘 등으로 약간 강조하면 커플 앱의 감성이 살아남

---

## 4. 구현 순서

### Phase 1 — 데이터 레이어
1. Supabase `owner_type` 컬럼 추가 + 마이그레이션 SQL
2. `Schedule` 모델에 `ownerType` 필드 추가
3. `ScheduleService` — 필터 제거, 전체 조회로 단순화

### Phase 2 — 달력 셀
4. `CalendarCell` 위젯 신규 작성 (바 표시, +N 오버플로우)
5. `CalendarScreen` — 필터 탭/범례 제거, CalendarCell 교체

### Phase 3 — 바텀시트
6. `DayDetailSheet` 신규 작성 (바텀시트, 정렬 로직)
7. 기존 `CalendarCard` 제거 또는 내부 로직만 재사용

### Phase 4 — 일정 추가 폼
8. `ScheduleAddSheet` 신규 작성 (소유자 선택, 스크롤 시간 피커)
9. 기존 `ScheduleAddDialog` 제거

### Phase 5 — 정리
10. 불필요 코드 제거: ScheduleFilter, _buildFilterBar, _buildLegend 등
11. 회귀 테스트: 기존 일정 조회, 기념일 자동 생성 유지 확인

---

## 5. 영향받는 파일

| 파일 | 변경 유형 |
|------|----------|
| `lib/shared/models/schedule.dart` | 수정 (ownerType 추가) |
| `lib/features/calendar/services/schedule_service.dart` | 수정 (필터 제거, 정렬 추가) |
| `lib/features/calendar/screens/calendar_screen.dart` | 대폭 수정 |
| `lib/features/calendar/widgets/calendar_card.dart` | 삭제 (CalendarCell로 교체) |
| `lib/features/calendar/widgets/schedule_add_dialog.dart` | 삭제 (ScheduleAddSheet로 교체) |
| `lib/features/calendar/widgets/schedule_detail.dart` | 유지 (상세 화면은 바텀시트에서 탭으로 연결) |
| **신규** `calendar_cell.dart` | 생성 |
| **신규** `day_detail_sheet.dart` | 생성 |
| **신규** `schedule_add_sheet.dart` | 생성 |

---

## 6. DB 마이그레이션 SQL

```sql
-- 1. owner_type 컬럼 추가
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS owner_type TEXT DEFAULT 'me'
  CHECK (owner_type IN ('me', 'partner', 'couple'));

-- 2. 기존 isDate=true 데이터를 couple로 마이그레이션
UPDATE schedules SET owner_type = 'couple' WHERE is_date = TRUE;

-- 3. 인덱스 (정렬 성능)
CREATE INDEX IF NOT EXISTS idx_schedules_owner_type ON schedules(owner_type);
```
