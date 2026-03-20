# 커플 프로필 설정 (온보딩 + 설정) Design Document

> **Summary**: 커플 상황(거리, 직종, 근무유형, 근무시간)을 4단계 온보딩으로 설정하고 FeatureFlag로 기능 자동 활성화
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Author**: Claude
> **Date**: 2026-03-18
> **Status**: Draft
> **Planning Doc**: [couple-profile-setup.plan.md](../01-plan/features/couple-profile-setup.plan.md)

---

## 1. Overview

### 1.1 Design Goals

- 온보딩을 3분 이내에 완료할 수 있도록 화면당 입력 항목 최소화
- 설정값 변경이 앱 전체 기능에 즉시 반영되는 반응형 FeatureFlag 시스템
- 파트너 연결 코드 기반의 안전한 1:1 커플 연결
- 근무 패턴 선택 시 스마트 기본값 자동 적용으로 입력 부담 제거

### 1.2 Design Principles

- **단순 우선**: 온보딩 각 Step은 1가지 주제만 다룸
- **스마트 기본값**: 선택 즉시 기본값 채움, 수정은 선택사항
- **설정 수정 가능**: 온보딩 완료 후 설정 화면에서 모든 항목 수정 가능
- **점진적 공개**: 선택한 옵션에 따라서만 추가 입력 필드 표시

---

## 2. Architecture

### 2.1 컴포넌트 구조

```
┌──────────────────────────────────────────────────────┐
│                   Flutter App                        │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │           OnboardingFlow                        │ │
│  │  Step1 → Step2 → Step3 → Step4 → HomeScreen    │ │
│  └─────────────────────────────────────────────────┘ │
│                        │                             │
│  ┌─────────────────────▼───────────────────────────┐ │
│  │         CoupleProfileProvider                   │ │
│  │  - 프로필 상태 관리                              │ │
│  │  - Supabase 저장/로드                           │ │
│  └─────────────────────────────────────────────────┘ │
│                        │                             │
│  ┌─────────────────────▼───────────────────────────┐ │
│  │           FeatureFlagProvider                   │ │
│  │  - 프로필 설정값 기반 기능 활성화/비활성화       │ │
│  │  - 앱 전체 위젯에서 참조                        │ │
│  └─────────────────────────────────────────────────┘ │
│                        │                             │
│            ┌───────────┴───────────┐                 │
│            ▼                       ▼                 │
│  ┌──────────────────┐   ┌─────────────────────────┐ │
│  │  Supabase DB     │   │  Supabase Realtime      │ │
│  │  couple_profiles │   │  파트너 설정 동기화     │ │
│  │  invite_codes    │   │                         │ │
│  └──────────────────┘   └─────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
온보딩 입력
    │
    ▼
CoupleProfileProvider.updateDraft()   ← 임시 저장 (로컬)
    │
    ▼ (완료 버튼)
CoupleProfileProvider.save()
    │
    ├──▶ Supabase couple_profiles upsert
    │
    └──▶ FeatureFlagProvider.refresh()
              │
              ├──▶ D-day 활성화 (사귄날짜 있으면)
              ├──▶ 교통편 추천 활성화 (장거리 + 역 설정)
              ├──▶ OCR 시간 자동기입 활성화 (교대근무)
              └──▶ 밤번 방해금지 활성화 (N 시프트 있으면)
```

### 2.3 Dependencies

| 컴포넌트 | 의존 | 목적 |
|----------|------|------|
| OnboardingStep2 | InviteCodeService | 초대 코드 생성/검증 |
| OnboardingStep3 | CityData | 도시/역 목록 |
| OnboardingStep4 | ShiftTimeDefaults | 근무 패턴별 기본값 |
| ProfileSettingsScreen | CoupleProfileProvider | 설정 읽기/쓰기 |
| FeatureFlagProvider | CoupleProfileProvider | 설정값 기반 플래그 계산 |

---

## 3. Data Model

### 3.1 CoupleProfile

```dart
class CoupleProfile {
  final String id;
  final String userId;
  final String? coupleId;              // 파트너와 공유하는 커플 UUID
  final String nickname;
  final DateTime coupleStartDate;

  // 거리 설정
  final DistanceType distanceType;
  final String? myCity;
  final String? myStation;             // '서울역', '수서역', '동서울터미널' 등
  final String? partnerCity;
  final String? partnerStation;

  // 근무 설정
  final WorkPatternType workPattern;
  final List<ShiftTime> shiftTimes;
  final int notifyMinutesBefore;       // 출근 알림 N분 전 (기본 30)

  // 교통 설정
  final bool hasCar;

  final DateTime createdAt;
  final DateTime updatedAt;

  // 파트너 연결 여부
  bool get isConnected => coupleId != null;

  // FeatureFlag 계산용 getter
  bool get hasShiftWork =>
      workPattern == WorkPatternType.shift_3 ||
      workPattern == WorkPatternType.shift_2;

  bool get isLongDistance =>
      distanceType == DistanceType.long_distance;

  bool get hasTransportInfo =>
      isLongDistance && myStation != null && partnerStation != null;

  bool get hasNightShift =>
      shiftTimes.any((s) => s.shiftType == 'N' || s.shiftType == 'night');
}

class ShiftTime {
  final String shiftType;      // 'D' | 'E' | 'N' | 'day' | 'night' | 'office'
  final String label;          // '낮번', '저녁번', '밤번', '주간', '야간', '근무'
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isNextDay;        // 종료가 익일인지 (밤번)

  // 근무 종료 DateTime 계산 (알림 스케줄링용)
  DateTime endDateTime(DateTime workDate) {
    final end = DateTime(workDate.year, workDate.month, workDate.day,
        endTime.hour, endTime.minute);
    return isNextDay ? end.add(const Duration(days: 1)) : end;
  }
}

enum DistanceType { same_city, near, long_distance }
enum WorkPatternType { shift_3, shift_2, office, other }
```

### 3.2 Entity Relationships

```
[auth.users] 1 ──── 1 [couple_profiles]
                           │
                    [couple_id] ──── [couple_id] (파트너의 couple_profiles)

[auth.users] 1 ──── N [invite_codes]
```

### 3.3 Supabase Schema

```sql
-- 커플 프로필
create table couple_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null unique,
  couple_id uuid,                    -- 파트너와 공유 UUID (연결 후 동일값)
  nickname text not null,
  couple_start_date date not null,
  distance_type text not null
    check (distance_type in ('same_city', 'near', 'long_distance')),
  my_city text,
  my_station text,
  partner_city text,
  partner_station text,
  work_pattern text not null
    check (work_pattern in ('shift_3', 'shift_2', 'office', 'other')),
  shift_times jsonb default '[]'::jsonb,
  notify_minutes_before integer default 30,
  has_car boolean default false,
  onboarding_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS: 본인 및 파트너만 조회 가능
alter table couple_profiles enable row level security;

create policy "본인 프로필 읽기/쓰기" on couple_profiles
  for all using (auth.uid() = user_id);

create policy "파트너 프로필 읽기" on couple_profiles
  for select using (
    couple_id is not null and
    couple_id = (
      select couple_id from couple_profiles
      where user_id = auth.uid()
    )
  );

-- 초대 코드
create table invite_codes (
  code text primary key,              -- 예: 'AB12-CD34' (8자리)
  user_id uuid references auth.users not null,
  used_by uuid references auth.users,
  is_used boolean default false,
  created_at timestamptz default now(),
  expires_at timestamptz default now() + interval '7 days'
);

alter table invite_codes enable row level security;

create policy "본인 코드 관리" on invite_codes
  for all using (auth.uid() = user_id);

create policy "코드 사용 (누구나)" on invite_codes
  for select using (not is_used and expires_at > now());
```

### 3.4 ShiftTime JSONB 형식

```json
[
  {
    "shift_type": "D",
    "label": "낮번",
    "start_hour": 6,
    "start_minute": 0,
    "end_hour": 15,
    "end_minute": 0,
    "is_next_day": false
  },
  {
    "shift_type": "E",
    "label": "저녁번",
    "start_hour": 13,
    "start_minute": 0,
    "end_hour": 22,
    "end_minute": 0,
    "is_next_day": false
  },
  {
    "shift_type": "N",
    "label": "밤번",
    "start_hour": 20,
    "start_minute": 0,
    "end_hour": 8,
    "end_minute": 0,
    "is_next_day": true
  }
]
```

---

## 4. API Specification

### 4.1 Supabase 호출 목록

| 작업 | 테이블 | 방식 | 설명 |
|------|--------|------|------|
| 프로필 저장/수정 | couple_profiles | upsert | 온보딩/설정 저장 |
| 프로필 로드 | couple_profiles | select | 앱 시작 시 |
| 파트너 프로필 로드 | couple_profiles | select (RLS) | couple_id 기반 |
| 초대 코드 생성 | invite_codes | insert | Step 2 진입 시 |
| 초대 코드 검증 | invite_codes | select | 상대 코드 입력 시 |
| 파트너 연결 | couple_profiles | update (2건) | 코드 검증 후 couple_id 동기화 |
| 파트너 설정 실시간 수신 | couple_profiles | realtime subscribe | 파트너 변경 감지 |

### 4.2 파트너 연결 플로우

```
A가 코드 생성 (invite_codes insert)
           │
B가 코드 입력
           │
           ▼
   코드 유효성 검증
   (is_used=false, expires_at 유효)
           │
           ▼
   couple_id = gen_random_uuid() 생성
           │
   ┌───────┴────────┐
   ▼                ▼
A 프로필         B 프로필
couple_id 업데이트  couple_id 업데이트
           │
           ▼
   invite_codes.is_used = true
```

### 4.3 ProfileService 인터페이스

```dart
class ProfileService {
  // 프로필 저장
  Future<void> saveProfile(CoupleProfile profile);

  // 프로필 로드 (본인)
  Future<CoupleProfile?> loadMyProfile();

  // 파트너 프로필 로드
  Future<CoupleProfile?> loadPartnerProfile();

  // 초대 코드 생성
  Future<String> generateInviteCode();

  // 초대 코드로 파트너 연결
  Future<bool> connectWithCode(String code);

  // 파트너 설정 변경 실시간 구독
  Stream<CoupleProfile> watchPartnerProfile();
}
```

---

## 5. UI/UX Design

### 5.1 온보딩 전체 플로우

```
앱 최초 실행
    │
    ▼
로그인/회원가입
    │
    ▼
온보딩 완료 여부 확인
    │
    ├─ completed=false ──▶ OnboardingFlow
    │                           │
    │                    Step1 (기본정보)
    │                           │
    │                    Step2 (파트너연결)  ← 나중에 연결도 가능
    │                           │
    │                    Step3 (거리설정)
    │                           │
    │                    Step4 (근무유형)
    │                           │
    │                    완료 → HomeScreen
    │
    └─ completed=true ───▶ HomeScreen
```

### 5.2 각 Step 화면 설계

#### Step 1 — 기본 정보
```
┌────────────────────────────────────┐
│  ← 로고                    1 / 4  │
├────────────────────────────────────┤
│                                    │
│  안녕하세요!                        │
│  먼저 간단히 소개해 주세요 :)        │
│                                    │
│  내 닉네임                          │
│  ┌──────────────────────────────┐  │
│  │  민준                        │  │
│  └──────────────────────────────┘  │
│                                    │
│  우리가 사귄 날짜                    │
│  ┌──────────────────────────────┐  │
│  │  2024년 6월 15일         📅  │  │
│  └──────────────────────────────┘  │
│                                    │
│  ┌──────────────────────────────┐  │
│  │           다음               │  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

#### Step 2 — 파트너 연결
```
┌────────────────────────────────────┐
│  ←                         2 / 4  │
├────────────────────────────────────┤
│                                    │
│  파트너를 초대해 주세요              │
│                                    │
│  내 초대 코드                        │
│  ┌──────────────────────────────┐  │
│  │       AB12-CD34          📋  │  │
│  └──────────────────────────────┘  │
│  [카카오톡으로 공유]                  │
│                                    │
│  ─────── 또는 ───────               │
│                                    │
│  파트너 코드 입력                    │
│  ┌──────────────────────────────┐  │
│  │  ____-____                   │  │
│  └──────────────────────────────┘  │
│  [연결하기]                          │
│                                    │
│  [나중에 연결할게요 →]               │  ← 스킵 가능
└────────────────────────────────────┘
```

#### Step 3 — 거리 설정
```
┌────────────────────────────────────┐
│  ←                         3 / 4  │
├────────────────────────────────────┤
│                                    │
│  서로 얼마나 멀리 있나요?            │
│                                    │
│  ┌──────────────────────────────┐  │
│  │  🏙️  같은 도시 (30분 이내)    │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  🚌  근거리 (1~2시간)         │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │ ← 선택됨
│  │  🚆  장거리 (다른 도시)   ✓  │  │
│  └──────────────────────────────┘  │
│                                    │
│  [장거리 선택 시 아래 표시]          │
│  ┌──────────────────────────────┐  │
│  │  내 도시      [서울    ▼]    │  │
│  │  내 역/터미널 [서울역  ▼]    │  │
│  ├──────────────────────────────┤  │
│  │  파트너 도시  [부산    ▼]    │  │
│  │  파트너 역    [부산역  ▼]    │  │
│  └──────────────────────────────┘  │
│  💡 교통편 추천에 자동 활용돼요      │
│                                    │
│  [다음]                             │
└────────────────────────────────────┘
```

#### Step 4 — 근무 유형
```
┌────────────────────────────────────┐
│  ←                         4 / 4  │
├────────────────────────────────────┤
│                                    │
│  어떤 형태로 일하세요?               │
│                                    │
│  ┌──────────────────────────────┐  │  ← 선택됨
│  │  👩‍⚕️  간호사/의료직 3교대  ✓  │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  🔄  교대 근무 2교대          │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  💼  일반 직장인 (주5일)      │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  🎨  기타 / 프리랜서          │  │
│  └──────────────────────────────┘  │
│                                    │
│  [3교대 선택 시 시간 설정 표시]      │
│  ┌──────────────────────────────┐  │
│  │  D 낮번   07:00 ~ 15:30  ✏️  │  │
│  │  E 저녁번  15:00 ~ 23:30  ✏️  │  │
│  │  N 밤번   23:00 ~ 07:30+1 ✏️ │  │
│  └──────────────────────────────┘  │
│  출근 [30]분 전 알림                 │
│                                    │
│  [시작하기 🎉]                      │
└────────────────────────────────────┘
```

### 5.3 설정 화면 — 프로필 설정

```
┌────────────────────────────────────┐
│  ←  프로필 설정                     │
├────────────────────────────────────┤
│                                    │
│  기본 정보                          │
│  ├ 내 닉네임          민준  >       │
│  └ 사귄 날짜    2024.06.15  >       │
│                                    │
│  파트너                             │
│  ├ 연결 상태      연결됨 💚  >      │
│  └ 파트너 닉네임      지수          │
│                                    │
│  우리의 거리                         │
│  ├ 거리 유형        장거리  >        │
│  ├ 내 도시/역  서울 · 서울역  >     │
│  └ 파트너 도시/역 부산 · 부산역  >  │
│                                    │
│  근무 설정                           │
│  ├ 근무 유형      간호사 3교대  >    │
│  ├ 근무 시간 설정                >   │
│  └ 출근 알림           30분 전  >   │
│                                    │
│  교통                               │
│  └ 내 차 보유 여부        없음  >    │
│                                    │
└────────────────────────────────────┘
```

### 5.4 근무 시간 편집 위젯 (ShiftTimeEditor)

```
┌────────────────────────────────────┐
│  근무 시간 설정                      │
├────────────────────────────────────┤
│                                    │
│  D  낮번                            │
│  시작  [07] : [00]                  │
│  종료  [15] : [30]                  │
│                                    │
│  E  저녁번                          │
│  시작  [15] : [00]                  │
│  종료  [23] : [30]                  │
│                                    │
│  N  밤번                            │
│  시작  [23] : [00]                  │
│  종료  [07] : [30]  (+익일)  ✓      │
│                                    │
│  [저장]                             │
└────────────────────────────────────┘
```

### 5.5 컴포넌트 목록

| 컴포넌트 | 위치 | 역할 |
|----------|------|------|
| OnboardingStep1Screen | onboarding/screens/ | 닉네임 + 사귄 날짜 |
| OnboardingStep2Screen | onboarding/screens/ | 파트너 초대 코드 |
| OnboardingStep3Screen | onboarding/screens/ | 거리 + 도시/역 선택 |
| OnboardingStep4Screen | onboarding/screens/ | 근무 유형 + 시간 |
| ShiftTimeEditor | onboarding/widgets/ | 시프트 시간 편집 |
| CitySelectorWidget | onboarding/widgets/ | 도시/역 드롭다운 |
| InviteCodeWidget | onboarding/widgets/ | 코드 생성/입력 |
| ProfileSettingsScreen | profile/screens/ | 전체 설정 수정 |

---

## 6. FeatureFlag 시스템

### 6.1 FeatureFlagProvider

```dart
class FeatureFlagProvider extends ChangeNotifier {
  CoupleProfile? _profile;

  void refresh(CoupleProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  // D-day 및 기념일
  bool get isDdayEnabled =>
      _profile?.coupleStartDate != null;

  // 교통편 추천
  bool get isTransportEnabled =>
      _profile?.hasTransportInfo == true;

  // OCR 시간 자동기입
  bool get isOcrAutoTimeEnabled =>
      _profile?.hasShiftWork == true &&
      (_profile?.shiftTimes.isNotEmpty == true);

  // 출퇴근 알림
  bool get isCommuteAlertEnabled =>
      _profile?.shiftTimes.isNotEmpty == true;

  // 밤번 후 방해금지
  bool get isNightShiftDndEnabled =>
      _profile?.hasNightShift == true;

  // 파트너 근무 상태 표시
  bool get isPartnerStatusEnabled =>
      _profile?.isConnected == true &&
      _profile?.hasShiftWork == true;
}
```

### 6.2 기능별 활성화 조건 요약

| 기능 | 활성화 조건 |
|------|------------|
| D-day 카운터 | coupleStartDate 입력됨 |
| 기념일 알림 (100일 등) | coupleStartDate 입력됨 |
| 교통편 추천 | distanceType=long_distance + myStation + partnerStation |
| 방문 순서 기록 | distanceType=long_distance |
| OCR 근무시간 자동기입 | workPattern=shift_3 or shift_2 + shiftTimes 있음 |
| 출퇴근 알림 | shiftTimes 있음 |
| 밤번 후 방해금지 | shiftTimes에 N 또는 night 포함 |
| 파트너 근무 상태 표시 | isConnected=true + 파트너 shiftTimes 있음 |
| 자차 교통 옵션 | hasCar=true |

---

## 7. 도시/역 데이터

### 7.1 주요 도시 + 역/터미널 매핑

```dart
const Map<String, List<String>> cityStations = {
  '서울': ['서울역(KTX)', '수서역(SRT)', '동서울터미널', '서울남부터미널'],
  '부산': ['부산역(KTX)', '부산종합터미널'],
  '대구': ['동대구역(KTX)', '대구서부터미널'],
  '광주': ['광주송정역(KTX)', '유스퀘어터미널'],
  '대전': ['대전역(KTX)', '대전복합터미널'],
  '울산': ['울산역(KTX)', '울산시외버스터미널'],
  '수원': ['수원역', '수원버스터미널'],
  '인천': ['인천터미널', '부평역'],
  '전주': ['전주역', '전주고속버스터미널'],
  '창원': ['창원역', '창원종합터미널'],
  '제주': ['제주공항', '서귀포터미널'],
  // 직접 입력: 목록에 없는 경우
};
```

---

## 8. Error Handling

| 상황 | 처리 |
|------|------|
| 초대 코드 만료 (7일 이상) | "코드가 만료됐어요. 파트너에게 새 코드를 받아보세요" |
| 이미 사용된 초대 코드 | "이미 사용된 코드예요" |
| 본인 코드 입력 | "내 코드는 입력할 수 없어요" |
| 온보딩 중 네트워크 오류 | 로컬 임시저장 후 재시도 안내 |
| 파트너 연결 후 프로필 미동기화 | Realtime 재구독 + 수동 새로고침 버튼 |

---

## 9. Security Considerations

- [ ] RLS: 본인 프로필만 수정 가능, 파트너 프로필은 읽기만
- [ ] 초대 코드 만료 (7일), 1회 사용 후 폐기
- [ ] couple_id 검증: 연결 시 서버사이드 트랜잭션으로 처리
- [ ] 닉네임 XSS 방지 (입력값 sanitize)

---

## 10. Test Plan

| 유형 | 대상 | 도구 |
|------|------|------|
| Unit | FeatureFlagProvider 플래그 계산 | flutter test |
| Unit | ShiftTime.endDateTime() 계산 | flutter test |
| Integration | 파트너 연결 플로우 | flutter test |
| Integration | Supabase RLS 검증 | Supabase Studio |
| E2E | 온보딩 4단계 완료 | flutter integration_test |

### 주요 테스트 케이스

- [ ] 3교대 선택 시 D/E/N 기본값 자동 적용
- [ ] 밤번(N) 종료 시각이 익일로 정확히 계산
- [ ] 장거리 선택 시만 도시/역 입력 필드 표시
- [ ] 파트너 연결 후 couple_id 양쪽 동일하게 저장
- [ ] 초대 코드 만료/중복 사용 오류 처리
- [ ] 온보딩 Step 2 스킵 후 나중에 연결 가능 확인

---

## 11. Implementation Guide

### 11.1 파일 구조

```
lib/
  features/
    onboarding/
      screens/
        onboarding_step1_screen.dart
        onboarding_step2_screen.dart
        onboarding_step3_screen.dart
        onboarding_step4_screen.dart
      widgets/
        shift_time_editor.dart
        city_selector_widget.dart
        invite_code_widget.dart
      onboarding_flow.dart            ← Step 라우팅 관리
    profile/
      screens/
        profile_settings_screen.dart
      models/
        couple_profile.dart
        shift_time.dart
      services/
        profile_service.dart
        invite_code_service.dart
      data/
        city_station_data.dart        ← 도시/역 정적 데이터
        shift_defaults.dart           ← 패턴별 기본값
  core/
    providers/
      couple_profile_provider.dart
      feature_flag_provider.dart
```

### 11.2 구현 순서

1. [ ] `couple_profile.dart` + `shift_time.dart` 모델 작성
2. [ ] Supabase 테이블 마이그레이션 실행
3. [ ] `profile_service.dart` — CRUD + 파트너 연결
4. [ ] `invite_code_service.dart` — 코드 생성/검증
5. [ ] `couple_profile_provider.dart` — 상태 관리
6. [ ] `feature_flag_provider.dart` — 플래그 계산
7. [ ] `city_station_data.dart` + `shift_defaults.dart` 정적 데이터
8. [ ] `onboarding_step1_screen.dart` ~ `step4_screen.dart`
9. [ ] `onboarding_flow.dart` — Step 라우팅
10. [ ] `profile_settings_screen.dart` — 설정 수정 화면
11. [ ] 앱 시작 시 온보딩 완료 여부 체크 로직

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-18 | Initial draft | Claude |
