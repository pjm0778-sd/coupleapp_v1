# 근무표 자동 입력 서비스 설계

> **Feature**: 스케줄 자동 입력 및 근무표 관리
> **Project**: coupleapp_v1
> **Version**: 1.0.0+2
> **Date**: 2026-03-10

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 교대 근무자와 일반 직장인 커플이 매달 스케줄을 하나하나 누르면서 작성하는 불편함, 근무형태별 최적 UI 부재 |
| **Solution** | 근무형태 설정(일반/3교대/2교대/4교대) + 디폴트 기능 + 공휴일 자동 표시로 사용자 맞춤형 UI 제공 |
| **Function/UX Effect** | 근무형태별 최적 UI + 공휴일 자동 표시 + 디폴트 적용으로 1분 만에 한 달 근무표 완성 가능 |
| **Core Value** | 커플 간 효율적 스케줄 관리 + 데이트 기회 놓치지 않음 (입력 시간 90% 단축) |

---

## 1. Overview

### 1.1 Purpose

사용자의 근무형태(일반 평일/직장인, 3교대, 2교대, 4교대, 일반 비정기)에 따라 최적의 스케줄 입력 방법을 제공하고, 공휴일을 자동으로 표시합니다. 또한 OCR 기능과 연동하여 근무표 이미지를 업로드하면 AI가 자동 분석합니다.

### 1.2 Background

- **현재 문제**: 모든 사용자에게 동일한 UI를 제공하여 교대/일반 근무자 불편함
- **사용자 요구사항**:
  - 근무형태별 최적 UI 필요
  - 공휴일 자동 표시 (대한민국 기준)
  - 디폴트 근무형태 설정
  - 예외 사항 개별 수정

### 1.3 Scope

#### 1.1 In Scope

- [ ] 근무형태 설정 화면
- [ ] 근무형태별 최적 UI 제공
- [ ] 공휴일 자동 표시 (대한민국)
- [ ] 디폴트 근무형태 설정
- [ ] 예외 사항 수정
- [ ] OCR 기능 연동

#### 1.2 Out of Scope

- [ ] 근무표 AI 자동 생성 (다음 단계)
- [ ] 복잡 패턴 학습 (시간 소요)

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────┐
│  Flutter App                        │
│  ┌──────────────────────────────────┐  │
│  │  ScheduleScreen               │  │
│  │  ┌─────────────────────────┐ │  │
│  │  │ CalendarView           │ │  │
│  │  │ - 공휴일 자동 표시 │ │  │
│  │  │ - 디폴트 적용       │ │  │
│  │  │ - 예외 수정           │ │  │
│  │  └─────────────────────────┘ │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ ShiftTypeScreen             │  │
│  │  - 근무형태 선택          │  │
│  │  - 디폴트 설정          │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ OCRService                 │  │
│  │  - 이미지 업로드          │  │
│  │  - AI 분석 (기존)        │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│   Supabase DB                          │
│  ┌──────────────────────────────────┐       │
│  │  user_settings               │       │
│  │  - shift_type               │       │
│  │  - default_shift            │       │
│  │  schedules                 │       │
│  └──────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
User 근무형태 선택
    │
    ▼
[ShiftTypeScreen 설정 저장]
    │
    ▼
[Supabase user_settings]
    │
    ▼
[ScheduleScreen]
    │
    ├─ [공휴일 API 자동 표시]
    ├─ [디폴트 근무형태 적용]
    └─ [예외 사항 수정]
    │
    ▼
[Supabase schedules]
```

---

## 3. Data Model

### 3.1 UserSettings 모델

```dart
class UserSettings {
  final String id;
  final String userId;
  final ShiftType shiftType;        // 근무형태
  final String defaultShift;          // 디폴트 근무형태
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.id,
    required this.userId,
    required this.shiftType,
    required this.defaultShift,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      shiftType: ShiftType.fromString(json['shift_type'] as String),
      defaultShift: json['default_shift'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'shift_type': shiftType.value,
      'default_shift': defaultShift,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
```

### 3.2 ShiftType Enum

```dart
enum ShiftType {
  regularOffice,     // 일반 평일/직장인
  shift3,            // 3교대 근무
  shift2,            // 2교대 근무
  shift4,            // 4교대 근무
  irregular;         // 일반 비정기

  String get value {
    switch (this) {
      case ShiftType.regularOffice:
        return 'regular_office';
      case ShiftType.shift3:
        return 'shift_3';
      case ShiftType.shift2:
        return 'shift_2';
      case ShiftType.shift4:
        return 'shift_4';
      case ShiftType.irregular:
        return 'irregular';
    }
  }

  String get displayName {
    switch (this) {
      case ShiftType.regularOffice:
        return '일반 평일/직장인';
      case ShiftType.shift3:
        return '3교대 근무';
      case ShiftType.shift2:
        return '2교대 근무';
      case ShiftType.shift4:
        return '4교대 근무';
      case ShiftType.irregular:
        return '일반 비정기';
    }
  }

  static ShiftType fromString(String value) {
    switch (value) {
      case 'regular_office':
        return ShiftType.regularOffice;
      case 'shift_3':
        return ShiftType.shift3;
      case 'shift_2':
        return ShiftType.shift2;
      case 'shift_4':
        return ShiftType.shift4;
      case 'irregular':
        return ShiftType.irregular;
      default:
        return ShiftType.regularOffice;
    }
  }
}
```

### 3.3 Holiday 모델

```dart
class Holiday {
  final DateTime date;
  final String name;
  final bool isNationwide;        // 전국 공휴일 여부

  Holiday({
    required this.date,
    required this.name,
    this.isNationwide = false,
  });
}
```

---

## 4. UI/UX Design

### 4.1 근무형태별 최적 UI 비교

| 근무형태 | 추천 UI | 장점 | 단점 |
|-----------|-----------|--------|--------|
| **일반 평일/직장인** | 달력 토글 | 클릭만으로 빠름, 모바일 친화적 | 고정된 순서만 가능 |
| **3교대** | AI OCR (기존) | 근무표 캡쳐서 업로드, AI 자동 분석 | 이미 구현됨 |
| **2교대** | 패턴 템플릿 | A/B/A/B/A 패턴 빠르게 적용 | 사용자 패턴 관리 필요 |
| **4교대** | 패턴 템플릿 | 4일 주기 특성상 유리 | 7일 단위 표시 필요 |
| **일반 비정기** | AI OCR + 수정 | 캡쳐 후 빠르게 입력, 유연하게 수정 | 매번 업로드 번거로움 |

### 4.2 공휴일 디폴트 기능

#### 대한민국 공휴일

| 날짜 | 휴무 |
|-------|------|
| 1월 1일 (신정) | 🟢 |
| 3월 1일 (삼일절) | 🟢 |
| 5월 5일 (어린이날) | 🟢 |
| 6월 6일 (현충일) | 🟢 |
| 추석 (음력 8월 15일) | 🟢 |
| 중추, 추석 전날 | 🟢 |
| 성묘, 성탄일 | 🟢 |
| 근로자의 날 (5월 1일) | 🟢 |
| 대체공휴일 | 🟢 |

### 4.3 일반 평일/직장인 UI (추천)

```
┌─────────────────────────────────────┐
│  3월 2026                      │
│  ┌─────────────────────────────┐   │
│  │ [일  월  화  목  금  토]    │   │
│  │  1   2   3   4   5          │   │
│  │  🟢  🟢  🟢  🟢  🟢         │ ← 평일은 디폴트 근무형태
│  │  6   7   8   9   10         │   │
│  │  🔵  🟢  🟢  🟢  🔵         │ ← 주말은 디폴트 휴무
│  │  11  12  13  14  15        │   │
│  │  🟢  🟢  🟢  🟢  🟢         │ ← 공휴일은 자동 휴무
│  │  ...                          │   │
│  └─────────────────────────────┘   │
│                                  │
│  📍 근무형태: 일반 평일/직장인 │
│  🏷 디폴트: 주간 근무          │
└─────────────────────────────────────┘
```

**특징:**
- 날짜 클릭 → 근무형태 순환 (주간근무/휴무/당직/휴가)
- 드래그 앤 드롭으로 연속 선택 → 일괄 적용
- 공휴일은 자동 표시, 수정 불가

### 4.4 근무형태 설정 화면

```
┌─────────────────────────────────────┐
│  근무형태 설정                  │
│  ┌─────────────────────────────┐   │
│  │ 근무형태 선택            │   │
│  │                        │   │
│  │  ⭕ 일반 평일/직장인   │   │
│  │  ⭕ 3교대 근무         │   │
│  │  ⭕ 2교대 근무         │   │
│  │  ⭕ 4교대 근무         │   │
│  │  ⭕ 일반 비정기        │   │
│  │                        │   │
│  ├─────────────────────┐   │
│  │ 디폴트 근무형태    │   │
│  │ [▼ 주간 근무]      │   │
│  │ [▼ 휴무]           │   │
│  │ [▼ 당직]           │   │
│  │ [▼ 휴가]           │   │
│  └─────────────────────┘   │
│  ───────────────────────────┘   │
│                                  │
│  [저장] [취소]              │
└─────────────────────────────────────┘
```

### 4.5 각 근무형태별 UI

#### 3교대 근무 (AI OCR)

```
┌─────────────────────────────────────┐
│  📸 근무표 이미지 업로드         │
│  ─────────────────────→         │
│  ✅ AI가 자동 분석 완료!         │
│                                  │
│  3월 1일: 🟢 주간근무         │
│  3월 2일: 🔵 나이트            │
│  3월 3일: 🟢 주간근무         │
│  ...                             │
│  [등록] [수정] [취소]           │
└─────────────────────────────────────┘
```

#### 2교대/4교대 근무 (패턴 템플릿)

```
┌─────────────────────────────────────┐
│  3월 2026                      │
│  ┌─────────────────────────────┐   │
│  │  패턴 템플릿 선택         │   │
│  │  ┌─────────────────────┐   │   │
│  │  │ A/B/A/B/A 패턴   │   │   │
│  │  └─────────────────────┘   │   │
│  │                          │   │
│  │  적용할 날짜 범위           │   │
│  │  [3월 1일] ~ [3월 31일]  │   │
│  │                          │   │
│  │  [적용 완료]               │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 5. Implementation Guide

### 5.1 구현 순서

1. [ ] `lib/core/models/shift_type.dart` 생성 - 근무형태 Enum
2. [ ] `lib/core/models/user_settings.dart` 생성 - 사용자 설정 모델
3. [ ] `lib/core/models/holiday.dart` 생성 - 공휴일 모델
4. [ ] `lib/features/schedule/services/holiday_service.dart` 생성 - 공휴일 API
5. [ ] `lib/features/schedule/screens/shift_type_screen.dart` 생성 - 근무형태 설정 화면
6. [ ] `lib/features/schedule/services/user_settings_service.dart` 생성 - 사용자 설정 서비스
7. [ ] `lib/features/schedule/screens/calendar_screen.dart` 생성 - 달력 화면 (근무형태별 UI 분기)
8. [ ] 메인 화면에 근무형태 설정 버튼 추가

### 5.2 DB 스키마

```sql
-- user_settings 테이블
CREATE TABLE user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  shift_type TEXT NOT NULL,
  default_shift TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_user_settings_user_id ON user_settings(user_id);
```

---

## 6. API Specification

### 6.1 Supabase RPC

| RPC | 설명 |
|-----|--------|
| `get_user_settings(user_id)` | 사용자 설정 조회 |
| `upsert_user_settings(user_id, shift_type, default_shift)` | 사용자 설정 저장/업데이트 |
| `get_public_holidays(year)` | 공공휴일 조회 (외부 API) |

---

## 7. Test Plan

| Type | Target | Tool |
|------|--------|------|
| Unit Test | 각 근무형태별 UI 로직 | flutter test |
| Integration Test | 공휴일 API 연동 | flutter test integration |
| E2E Test | 전체 플로우 테스트 | flutter test |

---

## 8. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|----------|------------|
| 공휴일 API 장애 | Medium | Low | 로컬 공휴일 백업 데이터 사용 |
| 근무형태별 UI 복잡성 | Medium | Medium | 공통 컴포넌트로 재사용 |
| 사용자 설정 동기화 | Low | Medium | 실시간 동기화 로직 추가 |

---

## 9. Success Criteria

- [ ] 근무형태 설정 화면 구현
- [ ] 각 근무형태별 최적 UI 구현
- [ ] 공휴일 자동 표시
- [ ] 디폴트 근무형태 설정
- [ ] 통합 테스트 완료

---

## 10. Next Steps

1. [ ] 구현 시작 (/pdca do ai_schedule)
2. [ ] 테스트
3. [ ] 배포
