# 공유 캘린더 및 OCR 일정 자동등록 설계

> **Feature**: 장거리 연애 커플을 위한 공유 캘린더 + OCR 일정 자동등록
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Date**: 2026-03-10

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | OCR 기능이 근무표 있는 사용자에만 유용하고, 공유 캘린더 기능이 제한적이며 UI가 직관적이지 않음 |
| **Solution** | OCR → 일반 일정 자동 변환 + Apple 스타일 캘린더 + 데이트 최적일 선정 + D-day 관리 + 기념일 자동 표시 |
| **Function/UX Effect** | 근무표 있으면 OCR로 일정 생성, 없으면 직접 입력 + 한눈에 D-day와 일정 확인 + 댓글로 소통 |
| **Core Value** | 장거리 커플 스케줄 공유 효율화 + 데이트 기회 증대 + 사용자 경험 개선 |

---

## 1. Overview

### 1.1 Purpose

장거리 연애 커플을 위한 공유 캘린더 시스템을 설계합니다. OCR로 분석된 근무표를 일반 일정으로 자동 등록하고, Apple 스타일의 직관적인 캘린더 UI를 제공합니다. 또한 양쪽 다 비거나 쉬는 날을 데이트 최적일로 추천하고, D-day와 기념일을 관리합니다.

### 1.2 Background

- **현재 문제**: 공유 캘린더가 색칠/이모지만 가능, OCR 기능이 근무표 사용자에만 유용
- **사용자 요구사항**:
  - OCR로 분석한 내용을 편집 가능한 일정으로 변환
  - Apple 스타일 직관적 캘린더
  - 필터로 나/파트너/둘 다 구분
  - 데이트 최적일 자동 추천
  - D-day 카운트다운
  - 기념일 자동 표시
  - 일정에 댓글 기능

### 1.3 Scope

#### 1.1 In Scope

- [ ] Schedules 테이블 확장 (title, 시간, 종류, 장소, 메모, 알림, 반복)
- [ ] ColorMappings 테이블 확장 (title, 시간)
- [ ] AnniversarySettings, ScheduleComments 테이블 신규
- [ ] Apple 스타일 캘린더 UI
- [ ] 일정 필터/토글
- [ ] 일정 상세 + 댓글/채팅
- [ ] 일정 자동등록 화면
- [ ] OCR → 일반 일정 자동 변환
- [ ] 데이트 최적일 선정
- [ ] D-day 관리
- [ ] 기념일 자동 표시

#### 1.2 Out of Scope

- [ ] AI 기반 근무 패턴 학습
- [ ] 복잡한 반복 패턴 (cron 스타일)

---

## 2. Architecture

### 2.1 Component Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                    Flutter App                             │
│                                                            │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │   HomeScreen    │  │ CalendarScreen  │              │
│  │                 │  │                 │              │
│  │  • D-day       │  │  • 카드형 UI  │              │
│  │  • 다음 데이트  │  │  • 필터/토글 │              │
│  │  • 오늘 일정   │  │  • 일정 추가  │              │
│  └─────────────────┘  └─────────────────┘              │
│                                                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           AutoRegistrationScreen                       │ │
│  │  • 색상 + 제목 + 시간 매핑                        │ │
│  │  • OCR 이미지 업로드                               │ │
│  └─────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────────────────────────┐
│               Service Layer                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ ScheduleSvc │  │AnniversarySvc│  │ CommentSvc  │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│  ┌─────────────┐  ┌─────────────┐                       │
│  │DateOptimalSvc│  │  HomeSvc    │                       │
│  └─────────────┘  └─────────────┘                       │
└───────────────────────────────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────────────────────────┐
│                    Supabase DB                            │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐          │
│  │ Schedules  │  │Anniversary│  │  Comments │          │
│  │           │  │ Settings  │  │           │          │
│  └───────────┘  └───────────┘  └───────────┘          │
└───────────────────────────────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────────────────────────┐
│              Edge Function                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ocr-schedule                                    │   │
│  │  • 기존 OCR 기능 유지                           │   │
│  │  • 매핑된 제목/시간 적용                       │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
[일정 자동등록 매핑 설정]
    │
    ▼
[ColorMappings 저장]
    │
    ▼
[OCR 이미지 업로드]
    │
    ▼
[OpenAI GPT-4o 분석]
    │
    ▼
[매핑 적용: 색상 → 제목+시간]
    │
    ▼
[Schedules에 일정 등록]
    │
    ▼
[파트너에게 실시간 공유]

===========================================

[캘린더 화면]
    │
    ├─ [필터 선택: 나만/파트너만/둘 다]
    │
    ├─ [일정 카드 탭 → 상세 화면]
    │       │
    │       ├─ [댓글 조회/작성]
    │       └─ [일정 수정/삭제]
    │
    └─ [날짜 길게 누르기/버튼 → 일정 추가]

===========================================

[홈 화면]
    │
    ├─ [D-day 조회]
    ├─ [다음 데이트 조회]
    ├─ [오늘 일정 요약]
    └─ [캘린더로 이동]
```

---

## 3. Data Model

### 3.1 Schedule 모델 (확장)

```dart
class Schedule {
  final String id;
  final String userId;
  final String? coupleId;
  final DateTime date;
  final String? title;              // 새로 추가
  final TimeOfDay? startTime;        // 새로 추가
  final TimeOfDay? endTime;          // 새로 추가
  final String? category;           // 새로 추가: '근무', '약속', '여행', '데이트', '기타'
  final String? location;           // 새로 추가
  final String? note;
  final int? reminderMinutes;        // 새로 추가: 알림 시간(분)
  final Map<String, dynamic>? repeatPattern; // 새로 추가: JSON 형식
  final bool isAnniversary;         // 새로 추가

  // OCR 관련 (원본 보관용)
  final String? workType;
  final String? colorHex;
  final bool isDate;
  final String? emoji;

  Schedule({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.date,
    this.title,
    this.startTime,
    this.endTime,
    this.category,
    this.location,
    this.note,
    this.reminderMinutes,
    this.repeatPattern,
    this.isAnniversary = false,
    this.workType,
    this.colorHex,
    this.isDate = false,
    this.emoji,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        coupleId: map['couple_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        title: map['title'] as String?,
        startTime: map['start_time'] != null
            ? _parseTime(map['start_time'] as String)
            : null,
        endTime: map['end_time'] != null
            ? _parseTime(map['end_time'] as String)
            : null,
        category: map['category'] as String?,
        location: map['location'] as String?,
        note: map['note'] as String?,
        reminderMinutes: map['reminder_minutes'] as int?,
        repeatPattern: map['repeat_pattern'] != null
            ? jsonDecode(map['repeat_pattern'] as String)
            : null,
        isAnniversary: map['is_anniversary'] as bool? ?? false,
        workType: map['work_type'] as String?,
        colorHex: map['color_hex'] as String?,
        isDate: map['is_date'] as bool? ?? false,
        emoji: map['emoji'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'couple_id': coupleId,
        'date': date.toIso8601String().split('T')[0],
        'title': title,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'category': category,
        'location': location,
        'note': note,
        'reminder_minutes': reminderMinutes,
        'repeat_pattern': repeatPattern != null
            ? jsonEncode(repeatPattern)
            : null,
        'is_anniversary': isAnniversary,
        'work_type': workType,
        'color_hex': colorHex,
        'is_date': isDate,
        'emoji': emoji,
      };

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

### 3.2 ColorMapping 모델 (확장)

```dart
class ColorMapping {
  final String id;
  final String userId;
  final String colorHex;
  final String title;              // 새로 추가
  final TimeOfDay? startTime;      // 새로 추가
  final TimeOfDay? endTime;        // 새로 추가

  ColorMapping({
    required this.id,
    required this.userId,
    required this.colorHex,
    required this.title,
    this.startTime,
    this.endTime,
  });

  factory ColorMapping.fromMap(Map<String, dynamic> map) => ColorMapping(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        colorHex: map['color_hex'] as String,
        title: map['title'] as String,
        startTime: map['start_time'] != null
            ? Schedule._parseTime(map['start_time'] as String)
            : null,
        endTime: map['end_time'] != null
            ? Schedule._parseTime(map['end_time'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'color_hex': colorHex,
        'title': title,
        'start_time': Schedule._formatTime(startTime),
        'end_time': Schedule._formatTime(endTime),
      };
}
```

### 3.3 AnniversarySetting 모델

```dart
class AnniversarySetting {
  final String id;
  final String coupleId;
  final String type;              // '100일', '1년', '화이트데이', '발렌타인', '크리스마스', '사용자정의'
  final String? customName;
  final int? customMonth;
  final int? customDay;
  final bool isEnabled;
  final List<int> reminderDays;    // 알림 기간 (일)

  AnniversarySetting({
    required this.id,
    required this.coupleId,
    required this.type,
    this.customName,
    this.customMonth,
    this.customDay,
    this.isEnabled = true,
    this.reminderDays = const [7, 1],
  });

  factory AnniversarySetting.fromMap(Map<String, dynamic> map) => AnniversarySetting(
        id: map['id'] as String,
        coupleId: map['couple_id'] as String,
        type: map['anniversary_type'] as String,
        customName: map['custom_name'] as String?,
        customMonth: map['custom_month'] as int?,
        customDay: map['custom_day'] as int?,
        isEnabled: map['is_enabled'] as bool? ?? true,
        reminderDays: (map['reminder_days'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [7, 1],
      );

  Map<String, dynamic> toMap() => {
        'couple_id': coupleId,
        'anniversary_type': type,
        'custom_name': customName,
        'custom_month': customMonth,
        'custom_day': customDay,
        'is_enabled': isEnabled,
        'reminder_days': reminderDays,
      };
}
```

### 3.4 ScheduleComment 모델

```dart
class ScheduleComment {
  final String id;
  final String scheduleId;
  final String userId;
  final String content;
  final DateTime createdAt;

  ScheduleComment({
    required this.id,
    required this.scheduleId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory ScheduleComment.fromMap(Map<String, dynamic> map) => ScheduleComment(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        userId: map['user_id'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'schedule_id': scheduleId,
        'user_id': userId,
        'content': content,
      };
}
```

### 3.5 RepeatPattern 형식

```json
{
  "type": "weekly",           // daily, weekly, monthly, yearly
  "days": [1, 3, 5],       // 요일 (1=월, 7=일)
  "startDate": "2026-03-10",
  "endDate": "2026-06-30",
  "interval": 1              // 반복 간격
}
```

---

## 4. UI/UX Design

### 4.1 홈 화면

```
┌─────────────────────────────────────────────────────────┐
│                                                     │
│  👩‍❤️‍👨                                            │
│  연애 125일                                          │
│                                                     │
│  ────────────────────────────────────────────────────   │
│                                                     │
│  📅                                                │
│  다음 데이트까지 3일 남음                             │
│  강남역 스타벅스 (3월 13일)                          │
│                                                     │
│  ────────────────────────────────────────────────────   │
│                                                     │
│  오늘의 일정                                        │
│  • 나: 정비공 (09:00-18:00)                         │
│  • 파트너: 휴일                                    │
│                                                     │
│  [캘린더로 이동 ▶]                                  │
│                                                     │
└─────────────────────────────────────────────────────────┘
```

- **D-day 위젯**: 연애 시작일 기준 카운트다운
- **다음 데이트 위젯**: 클릭 시 캘린더 해당 날짜로 이동
- **오늘 일정 위젯**: 클릭 시 캘린더 오늘 날짜로 이동

### 4.2 캘린더 화면 (Apple 스타일)

```
┌─────────────────────────────────────────────────────────┐
│  3월 2026                                  [+]   │
├─────────────────────────────────────────────────────────┤
│  🔄 필터: [나만] [파트너만] [둘 다]               │
├─────────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  3월 10일 (월)                             │   │
│  │                                            │   │
│  │  • 정비공 (09:00-18:00)  🟢 근무          │   │
│  │  • 팀 회의 (14:00-15:00)  🔵 약속         │   │
│  │                                            │   │
│  │  ─────────────────────────────────────────     │   │
│  │                                            │   │
│  │  💬 댓글 1개                                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  3월 11일 (화)                             │   │
│  │                                            │   │
│  │  • 데이트 (19:00-21:00)  💕 데이트         │   │
│  │    📍 강남역 스타벅스                        │   │
│  │                                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ...                                                 │
│                                                     │
└─────────────────────────────────────────────────────────┘
```

- **필터/토글**: 나만/파트너만/둘 다 선택
- **일정 카드**: 탭으로 상세 화면 이동
- **+ 버튼**: 일정 추가 다이얼로그
- **길게 누르기**: 해당 날짜에 일정 추가

### 4.3 일정 상세 화면

```
┌─────────────────────────────────────────────────────────┐
│  정비공                    [✏️ 수정] [🗑️ 삭제]        │
│  (내 일정)                                          │
├─────────────────────────────────────────────────────────┤
│  📅 날짜: 2026년 3월 10일 (월)                   │
│  🕐 시간: 09:00 - 18:00                            │
│  🏷️ 종류: 근무                                     │
│  📍 장소: [없음]                                   │
│  📝 메모: [없음]                                   │
│  🔔 알림: 1시간 전                                  │
│  🔁 반복: 없음                                      │
├─────────────────────────────────────────────────────────┤
│  💬 댓글 (1)                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │  파트너 (3/10 14:30)                       │   │
│  │  이번주 정비공 맞아?                        │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  나 (3/10 14:35)                           │   │
│  │  응 정비공이야                              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  [댓글 작성...]                                     │
└─────────────────────────────────────────────────────────┘
```

- **파트너 일정**: 수정/삭제 버튼 숨김, 읽기전용
- **댓글**: 실시간 표시, 스크롤 가능

### 4.4 일정 추가/수정 다이얼로그

```
┌─────────────────────────────────────────────────────────┐
│  일정 추가                                          │
├─────────────────────────────────────────────────────────┤
│  📅 날짜: [2026년 3월 10일 ▼]                    │
│  🕐 시간: [09:00] ~ [18:00]                         │
│                                                     │
│  🏷️ 제목: [정비공                      ] *         │
│  📍 장소: [                                ]        │
│  📝 메모: [                                  ]      │
│                                                     │
│  🔔 알림: [없음 ▼]                                  │
│         • 1시간 전                                   │
│         • 1일 전                                    │
│         • 직접 설정                                   │
│                                                     │
│  🔁 반복: [없음 ▼]                                  │
│         • 매일                                        │
│         • 매주                                        │
│         • 매월                                        │
│         • 사용자 정의                                  │
│                                                     │
│  ───────────────────────────────────────────────────   │
│                                                     │
│  [취소]                          [저장]           │
└─────────────────────────────────────────────────────────┘
```

### 4.5 일정 자동등록 화면

```
┌─────────────────────────────────────────────────────────┐
│  일정 자동등록                                      │
├─────────────────────────────────────────────────────────┤
│  [+ 새 매핑 추가]                                   │
├─────────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  색상: [🔴 빨강]                            │   │
│  │  제목: [정비공                      ] *       │   │
│  │  시간: [09:00] ~ [18:00]                     │   │
│  │       (야간근무: 21:00 ~ 09:00)               │   │
│  │                                            │   │
│  │                                [🗑️ 삭제]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  색상: [🔵 파랑]                            │   │
│  │  제목: [나이트                      ] *       │   │
│  │  시간: [21:00] ~ [09:00]  (야간근무)         │   │
│  │                                            │   │
│  │                                [🗑️ 삭제]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ───────────────────────────────────────────────────   │
│                                                     │
│  📸 OCR 이미지 업로드                               │
│  [선택파일 없음]                                      │
│                                                     │
│  [취소]                              [분석하기]   │
└─────────────────────────────────────────────────────────┘
```

### 4.6 데이트 최적일 화면

```
┌─────────────────────────────────────────────────────────┐
│  데이트 최적일 선정                                   │
├─────────────────────────────────────────────────────────┤
│                                                     │
│  🗓️ 3월 2026                                      │
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  3월 13일 (금)  💕  추천!                  │   │
│  │  • 나: 휴일                                   │   │
│  │  • 파트너: 휴일                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  3월 20일 (금)                              │   │
│  │  • 나: 휴일                                   │   │
│  │  • 파트너: 휴일                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  [캘린더로 이동]                                     │
└─────────────────────────────────────────────────────────┘
```

---

## 5. DB Schema

### 5.1 Schedules 테이블 확장

```sql
-- 기존 컬럼: id, user_id, couple_id, date, work_type, color_hex, note, is_date, emoji

ALTER TABLE schedules
ADD COLUMN IF NOT EXISTS title VARCHAR(200),
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME,
ADD COLUMN IF NOT EXISTS category VARCHAR(50)
  CHECK (category IN ('근무', '약속', '여행', '데이트', '기타')),
ADD COLUMN IF NOT EXISTS location VARCHAR(200),
ADD COLUMN IF NOT EXISTS reminder_minutes INT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS repeat_pattern JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_anniversary BOOLEAN DEFAULT FALSE;

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_schedules_category ON schedules(category);
CREATE INDEX IF NOT EXISTS idx_schedules_date_category ON schedules(date, category);
```

### 5.2 ColorMappings 테이블 확장

```sql
ALTER TABLE color_mappings
ADD COLUMN IF NOT EXISTS title VARCHAR(200) NOT NULL,
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME;
```

### 5.3 AnniversarySettings 테이블

```sql
CREATE TABLE IF NOT EXISTS anniversary_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  anniversary_type VARCHAR(50) NOT NULL,
  custom_name VARCHAR(100),
  custom_month INT,
  custom_day INT,
  is_enabled BOOLEAN DEFAULT TRUE,
  reminder_days INT[] DEFAULT ARRAY[7, 1],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_anniversary_settings_couple_id ON anniversary_settings(couple_id);
```

### 5.4 ScheduleComments 테이블

```sql
CREATE TABLE IF NOT EXISTS schedule_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_schedule_comments_schedule_id ON schedule_comments(schedule_id);
CREATE INDEX idx_schedule_comments_created_at ON schedule_comments(created_at DESC);
```

### 5.5 Couples 테이블 확장

```sql
ALTER TABLE couples
ADD COLUMN IF NOT EXISTS started_at DATE;
```

---

## 6. API Specification

### 6.1 ScheduleService

| Method | Description | Parameters |
|---------|-------------|-------------|
| `getMonthSchedules` | 해당 월의 커플 전체 일정 | `coupleId`, `month`, `filter` |
| `addSchedule` | 일정 추가 | `Schedule` |
| `updateSchedule` | 일정 수정 | `id`, `data` |
| `deleteSchedule` | 일정 삭제 | `id` |
| `getScheduleById` | 일정 상세 조회 | `id` |

### 6.2 DateOptimalService

| Method | Description | Parameters |
|---------|-------------|-------------|
| `getOptimalDays` | 데이트 최적일 조회 | `coupleId`, `startDate`, `endDate` |
| `getNextDateOptimalDay` | 가장 가까운 데이트 최적일 조회 | `coupleId` |

### 6.3 AnniversaryService

| Method | Description | Parameters |
|---------|-------------|-------------|
| `getAnniversaries` | 커플 기념일 조회 | `coupleId` |
| `addAnniversary` | 기념일 추가 | `AnniversarySetting` |
| `updateAnniversary` | 기념일 수정 | `id`, `data` |
| `deleteAnniversary` | 기념일 삭제 | `id` |
| `getAnniversaryDates` | 기념일 날짜 목록 조회 | `coupleId`, `year`, `month` |

### 6.4 CommentService

| Method | Description | Parameters |
|---------|-------------|-------------|
| `getComments` | 일정 댓글 조회 | `scheduleId` |
| `addComment` | 댓글 추가 | `scheduleId`, `content` |
| `deleteComment` | 댓글 삭제 | `id` |

### 6.5 HomeService

| Method | Description | Parameters |
|---------|-------------|-------------|
| `getDDays` | D-day 정보 조회 | `coupleId` |
| `getTodaySchedules` | 오늘의 일정 요약 | `coupleId` |
| `getNextDateSchedule` | 다음 데이트 조회 | `coupleId` |

---

## 7. Implementation Guide

### 7.1 구현 순서

#### 7.1.1 DB 마이그레이션

1. [ ] `supabase/migrations/20260310_schedules_extend.sql`
2. [ ] `supabase/migrations/20260310_color_mappings_extend.sql`
3. [ ] `supabase/migrations/20260310_anniversary_settings.sql`
4. [ ] `supabase/migrations/20260310_schedule_comments.sql`
5. [ ] `supabase/migrations/20260310_couples_started_at.sql`

#### 7.1.2 데이터 모델

6. [ ] `lib/shared/models/schedule.dart` 수정
7. [ ] `lib/shared/models/color_mapping.dart` 수정
8. [ ] `lib/shared/models/anniversary_setting.dart` 생성
9. [ ] `lib/shared/models/schedule_comment.dart` 생성
10. [ ] `lib/shared/models/repeat_pattern.dart` 생성

#### 7.1.3 서비스

11. [ ] `lib/features/calendar/services/schedule_service.dart` 확장
12. [ ] `lib/features/calendar/services/anniversary_service.dart` 생성
13. [ ] `lib/features/calendar/services/comment_service.dart` 생성
14. [ ] `lib/features/calendar/services/date_optimal_service.dart` 생성
15. [ ] `lib/features/home/services/home_service.dart` 생성

#### 7.1.4 UI - 캘린더

16. [ ] `lib/features/calendar/screens/calendar_screen.dart` 수정 (Apple 스타일)
17. [ ] `lib/features/calendar/widgets/calendar_card.dart` 생성
18. [ ] `lib/features/calendar/widgets/calendar_filter.dart` 생성
19. [ ] `lib/features/calendar/widgets/schedule_detail.dart` 생성
20. [ ] `lib/features/calendar/widgets/schedule_comments.dart` 생성
21. [ ] `lib/features/calendar/widgets/schedule_add_dialog.dart` 생성

#### 7.1.5 UI - 일정 자동등록

22. [ ] `lib/features/schedule/screens/auto_registration_screen.dart` 생성
23. [ ] `lib/features/schedule/widgets/color_mapping_card.dart` 생성
24. [ ] `lib/features/schedule/widgets/mapping_add_dialog.dart` 생성

#### 7.1.6 UI - 홈

25. [ ] `lib/features/home/screens/home_screen.dart` 생성
26. [ ] `lib/features/home/widgets/dday_widget.dart` 생성
27. [ ] `lib/features/home/widgets/next_date_widget.dart` 생성
28. [ ] `lib/features/home/widgets/today_schedule_widget.dart` 생성

#### 7.1.7 라우팅

29. [ ] `lib/main.dart` 라우터 업데이트

---

## 8. Test Plan

| Type | Target | Tool |
|------|--------|------|
| Unit Test | 서비스 로직, 모델 | flutter test |
| Integration Test | DB 연동, API 호출 | flutter test integration |
| E2E Test | 전체 플로우 | flutter test |

---

## 9. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|----------|------------|
| OCR 분석 오차 | Medium | Medium | 매핑된 정보 적용 + 사용자 수정 가능 |
| 야간근무 시각화 | Medium | Low | 시작 > 종료 시간으로 판단 |
| 실시간 공유 지연 | Low | Low | Supabase Realtime 사용 |
| 댓글 동기화 | Low | Low | Realtime 채널 사용 |

---

## 10. Success Criteria

- [ ] DB 마이그레이션 완료
- [ ] 데이터 모델 확장/생성 완료
- [ ] 서비스 구현 완료
- [ ] Apple 스타일 캘린더 UI 완료
- [ ] 일정 자동등록 화면 완료
- [ ] 홈 화면 완료
- [ ] OCR → 일정 자동 변환 완료
- [ ] 데이트 최적일 선정 완료
- [ ] D-day 관리 완료
- [ ] 기념일 자동 표시 완료
- [ ] 통합 테스트 완료

---

## 11. Next Steps

1. [ ] 구현 시작 (/pdca do ocr-calendar)
2. [ ] 테스트
3. [ ] 배포
