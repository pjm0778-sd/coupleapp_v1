# calendar-redesign Design

## 1. 아키텍처 개요

### 1.1 파일 구조 변화

```
lib/features/calendar/
├── screens/
│   └── calendar_screen.dart          ← 대폭 수정
├── services/
│   └── schedule_service.dart         ← 필터 제거, ownerType 정렬 추가
└── widgets/
    ├── calendar_cell.dart             ← 신규 (바 스타일 셀)
    ├── day_detail_sheet.dart          ← 신규 (바텀시트)
    ├── schedule_add_sheet.dart        ← 신규 (일정 추가 바텀시트)
    ├── schedule_detail.dart           ← 유지 (기존 상세 화면)
    ├── schedule_comments.dart         ← 유지
    ├── calendar_card.dart             ← 삭제
    └── schedule_add_dialog.dart       ← 삭제

lib/shared/models/
    └── schedule.dart                  ← ownerType 필드 추가
```

### 1.2 데이터 흐름

```
CalendarScreen
  ├── _loadSchedules() → ScheduleService.getMonthSchedules() (필터 제거)
  ├── _generateAnniversaries()  ← 유지
  ├── TableCalendar
  │   └── calendarBuilders.defaultBuilder → _CalendarCell (바 표시)
  │       └── onTap(bar) → DayDetailSheet (특정 일정으로 스크롤)
  ├── onDaySelected → DayDetailSheet.show() (바텀시트)
  └── FAB → ScheduleAddSheet.show() (일정 추가 바텀시트)
```

---

## 2. DB 변경 (Supabase)

### 2.1 owner_type 컬럼 추가

```sql
-- Supabase SQL Editor에서 실행
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS owner_type TEXT DEFAULT 'me'
  CHECK (owner_type IN ('me', 'partner', 'couple'));

-- 기존 isDate=true 데이터 마이그레이션
UPDATE schedules SET owner_type = 'couple' WHERE is_date = TRUE;

CREATE INDEX IF NOT EXISTS idx_schedules_owner_type
  ON schedules(owner_type);
```

### 2.2 owner_type 의미

| 값 | 의미 | 뱃지 텍스트 | 뱃지 색 |
|----|------|------------|---------|
| `couple` | 우리 일정 | `우` | 분홍 `#FF6B9D` |
| `me` | 내 일정 | `나` | 파랑 `#4F86F7` |
| `partner` | 파트너 일정 | `파` | 보라 `#9C6FE4` |

---

## 3. Schedule 모델 수정

### 3.1 `lib/shared/models/schedule.dart`

**추가할 필드:**
```dart
final String ownerType; // 'me' | 'partner' | 'couple'
```

**생성자 기본값:**
```dart
this.ownerType = 'me',
```

**fromMap:**
```dart
ownerType: map['owner_type'] as String? ?? 'me',
```

**toMap:**
```dart
'owner_type': ownerType,
```

**copyWith:**
```dart
String? ownerType,
// ...
ownerType: ownerType ?? this.ownerType,
```

---

## 4. ScheduleService 수정

### 4.1 `lib/features/calendar/services/schedule_service.dart`

**제거:**
- `ScheduleFilter` enum 전체
- `getMonthSchedules()`의 `filter` 파라미터 및 분기 로직

**수정 후 getMonthSchedules 서명:**
```dart
Future<List<Schedule>> getMonthSchedules(
  String coupleId,
  DateTime month,
) async {
  // 항상 coupleId 기준 전체 조회 (필터 없음)
  final data = await supabase
      .from('schedules')
      .select()
      .eq('couple_id', coupleId)
      .gte('date', firstDay)
      .lte('date', lastDay)
      .order('date');
  return data.map(Schedule.fromMap).toList();
}
```

**추가: 날짜별 일정 정렬 함수**
```dart
/// 우리(couple) → 내(me, myUserId) → 파트너 순 정렬
List<Schedule> sortByOwner(List<Schedule> schedules, String myUserId) {
  return [...schedules]..sort((a, b) {
    int orderA = _ownerOrder(a, myUserId);
    int orderB = _ownerOrder(b, myUserId);
    if (orderA != orderB) return orderA.compareTo(orderB);
    // 같은 그룹 내 시간순
    final ta = a.startTime;
    final tb = b.startTime;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return ta.hour * 60 + ta.minute - (tb.hour * 60 + tb.minute);
  });
}

int _ownerOrder(Schedule s, String myUserId) {
  if (s.ownerType == 'couple') return 0;
  if (s.ownerType == 'me' && s.userId == myUserId) return 1;
  return 2;
}
```

---

## 5. 신규 위젯 설계

### 5.1 `_CalendarCell` — 달력 셀 (바 표시)

> **위치**: `calendar_screen.dart` 내 private 위젯 또는 `calendar_cell.dart` 파일

**역할**: `TableCalendar`의 `calendarBuilders.defaultBuilder/selectedBuilder/todayBuilder`를 모두 이 위젯으로 대체

```dart
/// 달력 한 칸 (날짜 숫자 + 일정 바 최대 3개 + 오버플로우 표시)
class _CalendarCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final List<Schedule> events;     // 정렬된 일정 (ownerType 순)
  final List<Holiday> holidays;
  final String myUserId;
  final void Function(Schedule) onEventTap;  // 바 직접 탭 → 상세
  final Color Function(Schedule) getColor;
}
```

**레이아웃 구조:**
```
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // 날짜 숫자 + 공휴일명
    _DayNumber(day, isSelected, isToday, holidays),
    // 일정 바 (최대 3개)
    ...events.take(3).map(_EventBar),
    // +N 더보기
    if (events.length > 3) _OverflowText(events.length - 3),
    const Spacer(),
  ],
)
```

**_EventBar 위젯:**
```dart
class _EventBar extends StatelessWidget {
  // 높이: 15px, margin: 1px bottom, border-radius: 3px
  // 색상: schedule.colorHex or category default
  // 텍스트: schedule.title, overflow: ellipsis, 11px, white
  // onTap: 해당 일정 상세로 이동
}
```

**rowHeight 설정:**
```dart
TableCalendar(
  rowHeight: 86,  // 날짜(22) + 바3개(15*3=45) + 오버플로우(10) + 여백(9)
  ...
)
```

**기념일/공휴일 처리:**
- 기념일(`isAnniversary: true`) → 분홍 바, 탭 불가 (`onTap: null`)
- 공휴일 → 날짜 숫자 아래 공휴일명 표시 (기존 유지)

---

### 5.2 `DayDetailSheet` — 날짜 상세 바텀시트

**파일**: `lib/features/calendar/widgets/day_detail_sheet.dart`

```dart
class DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<Schedule> schedules;    // 정렬된 일정
  final List<Holiday> holidays;
  final String myUserId;
  final String? partnerNickname;
  final Color Function(Schedule) getColor;
  final Future<void> Function(Schedule) onEdit;
  final Future<void> Function(Schedule) onDelete;
  final VoidCallback onAddTap;

  static Future<void> show(BuildContext context, {required ...}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.88,
        builder: (_, controller) => DayDetailSheet(...),
      ),
    );
  }
}
```

**레이아웃:**
```
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  child: Column(
    children: [
      _DragHandle(),
      _DateHeader(date, holidays),    // "3월 19일 (목)"
      Divider(),
      Expanded(
        child: ListView(
          controller: scrollController,
          children: [
            // 기념일 배너 (있으면)
            if (anniversaries.isNotEmpty) _AnniversaryBanner(anniversaries),
            // 일정 없을 때
            if (nonAnniversarySchedules.isEmpty) _EmptyState(),
            // 일정 카드들 (우리 → 나 → 파트너 순)
            ...schedules.map(_ScheduleRow),
          ],
        ),
      ),
    ],
  ),
)
```

**_ScheduleRow 위젯:**
```dart
// 좌측 4px 컬러 바 + 소유자 뱃지 + 제목 + 시간 + ⋯ 메뉴
Container(
  decoration: BoxDecoration(
    border: Border(left: BorderSide(color: scheduleColor, width: 4)),
  ),
  child: Row(
    children: [
      _OwnerBadge(ownerType, myUserId),  // '우'/'나'/'파' 뱃지
      Expanded(child: Column(
        children: [
          Text(title),
          Text(timeRange),              // "오전 1:00 ~ 오전 2:00" / "종일"
        ],
      )),
      _MoreButton(onEdit, onDelete),    // ⋯ 탭 → ActionSheet
    ],
  ),
)
```

**_OwnerBadge:**
- `couple` → 분홍 배경, `우` (또는 ♡)
- `me` → 파랑 배경, `나`
- `partner` → 보라 배경, `파` (또는 파트너 이니셜)

**⋯ 메뉴 (showModalBottomSheet ActionSheet):**
```
수정하기
삭제하기
취소
```

---

### 5.3 `ScheduleAddSheet` — 일정 추가 바텀시트

**파일**: `lib/features/calendar/widgets/schedule_add_sheet.dart`

```dart
class ScheduleAddSheet extends StatefulWidget {
  final DateTime initialDate;
  final String myUserId;
  final String? partnerId;
  final String? partnerNickname;
  final String coupleId;
  final Schedule? existingSchedule;  // 수정 시 전달

  static Future<Schedule?> show(BuildContext context, {...}) =>
    showModalBottomSheet<Schedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ScheduleAddSheet(...),
      ),
    );
}
```

**폼 필드 순서 및 구현:**

```
1. 제목 TextField (autofocus: true)
   ─────────────────────────
2. 누구 일정? SegmentedButton
   [나] [파트너] [우리]
   ─────────────────────────
3. 하루종일 Switch
   ON  → 시간 섹션 숨김
   OFF → 시간 섹션 표시
   ─────────────────────────
4. 시작 날짜+시간 (하루종일=OFF일 때)
   [날짜] [시간 (CupertinoTimerPicker)]
5. 종료 날짜+시간 (하루종일=OFF일 때)
   [날짜] [시간 (CupertinoTimerPicker)]
   ─────────────────────────
6. 색상 팔레트 (19색, 3행)
   ─────────────────────────
7. 종류 Chip
   [근무] [약속] [여행] [데이트] [기타]
   ─────────────────────────
8. 장소 TextField (선택)
9. 메모 TextField multiline (선택)
   ─────────────────────────
[취소]        [저장]
```

**ownerType → userId 매핑 로직:**
```dart
String get _targetUserId {
  switch (_ownerType) {
    case 'partner': return widget.partnerId ?? widget.myUserId;
    default:        return widget.myUserId;
  }
}

// 저장 시
Schedule(
  userId: _targetUserId,
  coupleId: widget.coupleId,
  ownerType: _ownerType,  // 'me' | 'partner' | 'couple'
  isDate: _ownerType == 'couple',  // 하위 호환성 유지
  startTime: _isAllDay ? null : _startTime,
  endTime:   _isAllDay ? null : _endTime,
  ...
)
```

**시간 선택 UX (CupertinoTimerPicker 스크롤):**
```dart
// 시간 선택 시 바텀시트 내에서 인라인 스크롤 위젯으로 표시
// showTimePicker 대신 SizedBox(height: 150) + CupertinoTimerPicker
CupertinoTimerPicker(
  mode: CupertinoTimerPickerMode.hm,
  onTimerDurationChanged: (duration) { ... },
)
```
→ 날짜 탭 시 → `showDatePicker` (기존 방식 유지)
→ 시간 탭 시 → inline CupertinoTimerPicker expand/collapse

---

## 6. CalendarScreen 수정 사항

### 6.1 제거할 요소들

| 제거 대상 | 코드 위치 |
|-----------|-----------|
| `ScheduleFilter _filter` 상태 변수 | line 24 |
| `_onFilterChanged()` 메서드 | line 157 |
| `_buildFilterBar()` 메서드 | 전체 |
| `_buildLegend()` 메서드 | 전체 |
| `bool _showCalendarGrid` 상태 변수 | line 30 |
| `_buildCalendarList()` 메서드 | 전체 |
| `_showAddDialog()` 내 filter 분기 로직 | line 557~589 |
| `import schedule_add_dialog.dart` | line 9 |
| `import calendar_card.dart` | line 11 |

### 6.2 수정할 요소들

**`_loadSchedules()` 서명 변경:**
```dart
// before
final list = await _service.getMonthSchedules(_coupleId!, month, filter: _filter);

// after
final list = await _service.getMonthSchedules(_coupleId!, month);
// 로드 후 각 날짜별 정렬 적용
map[key] = _service.sortByOwner(map[key]!, _myUserId!);
```

**`build()` body 변경:**
```dart
// before
body: Column(children: [
  _buildFilterBar(),
  if (_filter == ScheduleFilter.both) _buildLegend(),
  Divider(),
  if (_showCalendarGrid) _buildTableCalendar(),
  if (_showCalendarGrid) Divider(),
  Expanded(child: _isLoading ? ... : _showCalendarGrid ? ... : ...),
])

// after
body: Column(children: [
  _buildTableCalendar(),   // 항상 표시
  Divider(height: 1),
  if (_isLoading) LinearProgressIndicator(),
])
```

**onDaySelected → DayDetailSheet:**
```dart
onDaySelected: (selectedDay, focusedDay) {
  setState(() { _selectedDay = selectedDay; _focusedMonth = focusedDay; });
  final events = _getEventsForDay(selectedDay);
  final holidays = _getHolidaysForDay(selectedDay);
  DayDetailSheet.show(
    context,
    date: selectedDay,
    schedules: _service.sortByOwner(events, _myUserId!),
    holidays: holidays,
    myUserId: _myUserId!,
    partnerNickname: _partnerNickname,
    getColor: _getScheduleColor,
    onEdit: _editScheduleItem,
    onDelete: _deleteScheduleItem,
    onAddTap: () => _showAddSheet(selectedDay),
  );
},
```

**calendarBuilders 변경:**
```dart
calendarBuilders: CalendarBuilders<Schedule>(
  // 모든 날짜 셀을 _CalendarCell로 통일
  defaultBuilder: (ctx, day, _) => _buildCell(day, false, false),
  selectedBuilder: (ctx, day, _) => _buildCell(day, true, false),
  todayBuilder: (ctx, day, _) => _buildCell(day, false, true),
  // markerBuilder 제거 (바는 defaultBuilder 내부에서 처리)
),

Widget _buildCell(DateTime day, bool isSelected, bool isToday) {
  final events = _getEventsForDay(day);
  final sorted = _service.sortByOwner(events, _myUserId ?? '');
  return _CalendarCell(
    day: day,
    isSelected: isSelected,
    isToday: isToday,
    events: sorted,
    holidays: _getHolidaysForDay(day),
    myUserId: _myUserId ?? '',
    getColor: _getScheduleColor,
    onEventTap: (s) => _onScheduleTap(s),
  );
}
```

**FAB → ScheduleAddSheet:**
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _showAddSheet(null),
  backgroundColor: AppTheme.primary,
  child: const Icon(Icons.add),
),

void _showAddSheet(DateTime? date) async {
  final result = await ScheduleAddSheet.show(
    context,
    initialDate: date ?? _selectedDay,
    myUserId: _myUserId!,
    partnerId: _partnerId,
    partnerNickname: _partnerNickname,
    coupleId: _coupleId!,
  );
  if (result != null && mounted) {
    await _service.addSchedule(result);
    _loadSchedules(_focusedMonth);
  }
}
```

---

## 7. 구현 시 주의사항

### 7.1 table_calendar rowHeight

기존 `rowHeight`가 기본값(52)일 경우 바 3개가 들어가지 않음.
```dart
TableCalendar(
  rowHeight: 86,  // 필수 조정
  daysOfWeekHeight: 32,
  ...
)
```

### 7.2 isDate 하위 호환성

`ownerType='couple'` 저장 시 `isDate: true` 도 함께 저장해서
아직 `ownerType` 컬럼 마이그레이션 전 데이터와 호환 유지:
```dart
isDate: _ownerType == 'couple',
owner_type: _ownerType,
```

### 7.3 기존 isDate=true 데이터 처리

DB 마이그레이션 전 기존 데이터에서 `ownerType`이 null이면:
```dart
// fromMap에서
ownerType: map['owner_type'] as String?
    ?? (map['is_date'] as bool? == true ? 'couple' : 'me'),
```

### 7.4 파트너 일정 등록 (owner_type='partner')

파트너 일정으로 선택 시 `userId`는 내 userId 사용, `ownerType='partner'`.
파트너의 `userId`로 저장하면 RLS 정책에 의해 거부될 수 있음.
→ 내 userId로 저장하되 ownerType으로 구분.

### 7.5 DraggableScrollableSheet + 키보드

`ScheduleAddSheet`에서 텍스트 입력 시 키보드가 올라오면 폼이 가려짐.
`Padding(padding: EdgeInsets.only(bottom: viewInsets.bottom))` 필수.

---

## 8. 구현 순서 체크리스트

```
[ ] 1. DB: owner_type 컬럼 추가 SQL 실행
[ ] 2. Schedule 모델: ownerType 필드 추가 (fromMap/toMap/copyWith)
[ ] 3. ScheduleService: 필터 제거, sortByOwner 추가
[ ] 4. _CalendarCell 위젯 구현 (바 + 숫자 + 오버플로우)
[ ] 5. DayDetailSheet 구현
[ ] 6. ScheduleAddSheet 구현 (소유자 선택 + 스크롤 시간 피커)
[ ] 7. CalendarScreen 수정 (필터 제거, 새 위젯 연결)
[ ] 8. 구 파일 삭제: calendar_card.dart, schedule_add_dialog.dart
[ ] 9. 기존 일정 조회·기념일·Realtime 정상 동작 확인
```
