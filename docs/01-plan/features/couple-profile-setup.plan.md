# 커플 프로필 설정 (온보딩 + 설정) Planning Document

> **Summary**: 커플 상황(거리, 직종, 근무유형, 근무시간)을 온보딩에서 설정하고, 이를 기반으로 앱 기능을 자동 활성화하는 커플 프로필 시스템
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Author**: Claude
> **Date**: 2026-03-18
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 간호사 커플 등 다양한 상황의 커플이 하나의 앱을 쓰기에 기능이 범용적이거나, 반대로 특정 상황만 지원해 다른 커플에게는 불필요한 기능이 많음 |
| **Solution** | 온보딩에서 커플 상황(거리, 직종, 근무패턴, 근무시간)을 4단계로 간단히 설정하고, 설정값에 따라 관련 기능을 자동 활성화 |
| **Function/UX Effect** | 2~3분 온보딩으로 나에게 맞는 앱 구성 완성 — 필요 없는 기능은 숨겨지고, 필요한 기능은 자동으로 연결됨 |
| **Core Value** | "우리 상황에 딱 맞는 앱" — 간호사+일반직장인 커플부터 동일 교대 커플까지 모든 상황 지원 |

---

## 1. Overview

### 1.1 Purpose

커플의 상황(장거리 여부, 직종, 근무 패턴, 근무 시간 등)을 온보딩에서 설정하고, 이 정보를 기반으로 앱의 다양한 기능들이 자동으로 연계되도록 합니다. 온보딩 이후에도 설정 화면에서 언제든지 수정 가능합니다.

### 1.2 Background

- 현재 앱은 단일 커플(개발자 본인 + 간호사 여자친구)을 위해 설계됨
- 다양한 커플 상황을 지원하려면 **상황별 기능 분기**가 필요
- 근무 시간 정보가 없으면 OCR 시간 자동기입, 출퇴근 알림 등 고급 기능 사용 불가
- 장거리 여부를 모르면 교통편 추천 등 기능 활성화 불가

### 1.3 Related Documents

- OCR 스케줄 프롬프트: `docs/01-plan/features/ocr-schedule-prompt.plan.md`
- 알림 기능: `docs/01-plan/features/notifications.plan.md`
- AI 근무표 생성: `docs/01-plan/features/ai_schedule.plan.md`

---

## 2. Scope

### 2.1 In Scope

- [ ] 온보딩 4단계 화면 구현
- [ ] 파트너 연결 (초대 코드 생성/입력)
- [ ] 근무 패턴별 근무 시간 설정 (스마트 기본값 포함)
- [ ] 설정 화면에서 모든 항목 수정 가능
- [ ] 설정값 → Supabase 저장 및 동기화
- [ ] 설정값 기반 기능 활성화/비활성화 로직

### 2.2 Out of Scope

- 선호 교통편 상세 설정 (교통 추천 기능 구현 시 추가)
- 커플 사진/프로필 이미지 (이후 단계)
- 소셜 로그인 계정 연동 변경
- 다중 파트너 (1:1 커플만 지원)

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 온보딩 Step 1: 닉네임 + 사귄 날짜 입력 | High | Pending |
| FR-02 | 온보딩 Step 2: 초대 코드로 파트너 연결 | High | Pending |
| FR-03 | 온보딩 Step 3: 거리 유형 선택 (같은 도시 / 근거리 / 장거리) | High | Pending |
| FR-04 | 온보딩 Step 3: 장거리 선택 시 각자 거주 도시 입력 | High | Pending |
| FR-04a | 장거리 선택 시 각자 주요 이용 역/터미널 설정 (KTX역, SRT역, 버스터미널 등) | High | Pending |
| FR-04b | 설정된 출발지/도착지 정보를 교통편 추천 기능에 자동 전달 | High | Pending |
| FR-05 | 온보딩 Step 4: 직종 및 근무 패턴 선택 | High | Pending |
| FR-06 | 근무 패턴 선택 시 근무 시간 스마트 기본값 자동 채움 | High | Pending |
| FR-07 | 근무 시간 직접 수정 가능 (기본값 오버라이드) | High | Pending |
| FR-08 | 차량 보유 여부 설정 (설정 화면, 온보딩 생략 가능) | Medium | Pending |
| FR-09 | 설정 화면에서 모든 온보딩 항목 수정 가능 | High | Pending |
| FR-10 | 설정값 기반 기능 활성화 로직 (FeatureFlag 시스템) | High | Pending |
| FR-11 | 파트너와 설정 정보 실시간 동기화 | High | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| UX | 온보딩 완료 시간 3분 이내 | 사용자 테스트 |
| UX | 각 온보딩 Step이 1화면에 완결 | UI 리뷰 |
| Performance | 설정 저장 응답 2초 이내 | Supabase 응답 측정 |
| Reliability | 온보딩 도중 이탈 후 재진입 시 진행 상태 유지 | 테스트 |

---

## 4. 온보딩 플로우 상세

### 4.1 4단계 플로우

```
Step 1. 기본 정보 (필수, ~30초)
┌─────────────────────────────────┐
│  내 닉네임: [____________]       │
│  사귄 날짜: [2024. 06. 15 ▼]    │
└─────────────────────────────────┘

Step 2. 파트너 연결 (필수)
┌─────────────────────────────────┐
│  내 초대 코드: AB12-CD34         │
│  [코드 복사] [카카오톡 공유]      │
│                                 │
│  파트너 코드 입력: [______]      │
└─────────────────────────────────┘

Step 3. 우리의 거리 (필수)
┌─────────────────────────────────┐
│  ○ 같은 도시 (30분 이내)         │
│  ○ 근거리 (1~2시간)              │
│  ● 장거리 (다른 도시)            │
│                                 │
│  [장거리 선택 시 표시]           │
│  내 거주 도시:    [서울 ▼]       │
│  내 주요 역/터미널: [서울역 ▼]   │
│    → KTX역 / SRT역 / 버스터미널  │
│                                 │
│  파트너 거주 도시: [부산 ▼]      │
│  파트너 역/터미널: [부산역 ▼]    │
│                                 │
│  💡 교통편 추천에 자동으로 활용   │
│     됩니다. 나중에 수정 가능해요. │
└─────────────────────────────────┘

Step 4. 내 근무 유형 (필수)
┌─────────────────────────────────┐
│  ○ 간호사 / 의료직 3교대         │
│  ○ 교대 근무 2교대              │
│  ○ 일반 직장인 (주5일)           │
│  ○ 기타 / 프리랜서              │
│                                 │
│  [3교대 선택 시 시간 설정 표시]  │
│  D (낮번)  07:00 ~ 15:30        │
│  E (저녁번) 15:00 ~ 23:30      │
│  N (밤번)  23:00 ~ 07:30 (+1)  │
│                                 │
│  출근 알림: [30]분 전            │
└─────────────────────────────────┘
```

### 4.2 근무 패턴별 스마트 기본값

| 패턴 | 시프트 | 기본 시작 | 기본 종료 |
|------|--------|-----------|-----------|
| 3교대 | D (낮번) | 07:00 | 15:30 |
| 3교대 | E (저녁번) | 15:00 | 23:30 |
| 3교대 | N (밤번) | 23:00 | 07:30 (+익일) |
| 2교대 | 주간 | 07:00 | 19:00 |
| 2교대 | 야간 | 19:00 | 07:00 (+익일) |
| 일반직장인 | 출근 | 09:00 | 18:00 |

> 기본값은 자동 입력되며, 사용자가 본인 병원/회사 시간에 맞게 수정 가능

---

## 5. 기능 활성화 매핑 (FeatureFlag)

설정값에 따라 자동으로 활성화되는 기능:

| 설정값 | 활성화되는 기능 |
|--------|----------------|
| 사귄 날짜 입력 | D-day 카운터, 기념일 알림 (100일/200일/1년) |
| 장거리 + 도시 설정 | 교통편 추천, 방문 순서 기록 |
| 근무 패턴 = 교대 | OCR 근무 시간 자동기입, 파트너 근무 상태 표시 |
| 근무 시간 설정 완료 | 출퇴근 알림, 밤번 후 방해금지 자동 ON |
| 차량 보유 설정 | 교통 추천에 자차 옵션 포함 |

---

## 6. 데이터 모델

### 6.1 CoupleProfile 모델

```dart
class CoupleProfile {
  final String userId;
  final String nickname;
  final DateTime coupleStartDate;     // 사귄 날짜

  // 거리 설정
  final DistanceType distanceType;    // same_city / near / long_distance
  final String? myCity;               // 장거리 시 내 도시
  final String? myStation;            // 내 주요 역/터미널 (예: '서울역', '수서역', '동서울터미널')
  final String? partnerCity;          // 장거리 시 파트너 도시
  final String? partnerStation;       // 파트너 주요 역/터미널 (예: '부산역', '부산종합터미널')

  // 근무 설정
  final WorkPatternType workPattern;  // shift_3 / shift_2 / office / other
  final List<ShiftTime> shiftTimes;   // 시프트별 시간 설정

  // 교통 설정 (선택)
  final bool? hasCar;
}

class ShiftTime {
  final String shiftType;   // 'D', 'E', 'N', 'day', 'night', 'office'
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isNextDay;     // 익일 종료 여부 (밤번)
}

enum DistanceType { same_city, near, long_distance }
enum WorkPatternType { shift_3, shift_2, office, other }
```

### 6.2 Supabase 테이블

```sql
-- couple_profiles 테이블
create table couple_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  couple_id uuid,                    -- 파트너와 연결된 커플 ID
  nickname text not null,
  couple_start_date date not null,
  distance_type text not null,       -- 'same_city' | 'near' | 'long_distance'
  my_city text,
  my_station text,                   -- 내 주요 역/터미널 (교통편 추천 출발지)
  partner_city text,
  partner_station text,              -- 파트너 주요 역/터미널 (교통편 추천 도착지)
  work_pattern text not null,        -- 'shift_3' | 'shift_2' | 'office' | 'other'
  shift_times jsonb,                 -- ShiftTime 배열
  has_car boolean,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- invite_codes 테이블 (파트너 연결용)
create table invite_codes (
  code text primary key,
  user_id uuid references auth.users not null,
  used_by uuid references auth.users,
  created_at timestamptz default now(),
  expires_at timestamptz
);
```

---

## 7. Architecture Considerations

### 7.1 Project Level Selection

| Level | Characteristics | Selected |
|-------|-----------------|:--------:|
| **Starter** | Simple structure | ☐ |
| **Dynamic** | Feature-based modules, BaaS integration | ☑ |
| **Enterprise** | Strict layer separation, microservices | ☐ |

### 7.2 Key Architectural Decisions

| Decision | Selected | Rationale |
|----------|----------|-----------|
| Framework | Flutter | 기존 프로젝트 |
| State Management | Provider | 기존 프로젝트 |
| Backend | Supabase | 기존 프로젝트 |
| 설정값 전파 | FeatureFlag Provider | 앱 전체에서 설정값 참조 |

### 7.3 폴더 구조

```
lib/features/
  onboarding/
    screens/
      onboarding_step1_screen.dart    # 닉네임 + 사귄 날짜
      onboarding_step2_screen.dart    # 파트너 연결
      onboarding_step3_screen.dart    # 거리 설정
      onboarding_step4_screen.dart    # 근무 유형 + 시간
    widgets/
      shift_time_editor.dart          # 근무 시간 편집 위젯
      city_selector.dart              # 도시 선택 위젯
      invite_code_widget.dart         # 초대 코드 생성/입력
  profile/
    screens/
      profile_settings_screen.dart    # 설정 화면 (온보딩 항목 수정)
    models/
      couple_profile.dart
      shift_time.dart
    services/
      profile_service.dart            # Supabase CRUD
      invite_code_service.dart        # 초대 코드 관리
  core/
    providers/
      feature_flag_provider.dart      # 설정값 기반 기능 활성화
      couple_profile_provider.dart
```

---

## 8. Success Criteria

### 8.1 Definition of Done

- [ ] 온보딩 4단계 화면 구현 완료
- [ ] 파트너 초대 코드 생성/입력 동작
- [ ] 근무 시간 스마트 기본값 + 수정 동작
- [ ] 설정 화면에서 전체 항목 수정 가능
- [ ] FeatureFlag 기반 기능 활성화 로직 동작
- [ ] Supabase 저장 및 파트너 간 동기화 확인

### 8.2 Quality Criteria

- [ ] 온보딩 완료 시간 3분 이내
- [ ] 온보딩 도중 이탈 후 재진입 시 상태 복원
- [ ] 설정 변경 즉시 앱 기능에 반영

---

## 9. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 파트너 연결 전 앱 사용 시 기능 제한 | Medium | High | 파트너 연결 없이도 기본 기능 사용 가능하도록 |
| 근무 시간 기본값이 병원마다 다름 | Low | High | 스마트 기본값 제공 후 수정 유도 |
| 도시 목록 관리 (전국 도시) | Low | Medium | 주요 도시 선택지 + 직접 입력 옵션 |
| 설정 변경 시 기존 알림/데이터와 충돌 | Medium | Medium | 설정 변경 시 관련 알림 재스케줄링 |

---

## 10. Next Steps

1. [ ] Design document 작성 (`couple-profile-setup.design.md`)
2. [ ] 온보딩 UI 목업 작성
3. [ ] Supabase 테이블 마이그레이션
4. [ ] 구현 시작

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-18 | Initial draft | Claude |
