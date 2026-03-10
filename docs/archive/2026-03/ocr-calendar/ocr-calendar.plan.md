# 공유 캘린더 및 OCR 일정 자동등록

> **Feature**: 장거리 연애 커플을 위한 공유 캘린더 + OCR 일정 자동등록
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Date**: 2026-03-10

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | OCR 기능이 근무표 있는 사용자에만 유용하고, 공유 캘린더 기능이 제한적(색칠, 이모지만 가능)이며 캘린더 UI가 직관적이지 않음 |
| **Solution** | OCR로 분석된 내용을 일반 일정으로 자동 등록 + Apple 스타일 공유 캘린더 UI + 데이트 최적일 선정 + D-day 관리 |
| **Function/UX Effect** | 근무표 있으면 OCR로 한 번에 일정 생성, 없으면 직접 입력으로 공유 캘린더 구축, 한눈에 D-day와 일정 확인 |
| **Core Value** | 장거리 커플 스케줄 공유 효율화 + 데이트 기회 증대 + 사용자 경험 개선 |

---

## 1. Overview

### 1.1 Purpose

장거리 연애 커플이 서로의 스케줄을 쉽게 공유하고, 가장 데이트하기 좋은 날을 찾으며, 만남까지 남은 기간을 확인할 수 있는 MVP 기능을 구현합니다. OCR 기능을 확장하여 근무표가 있는 사용자는 일정을 자동으로 등록할 수 있도록 하고, 공유 캘린더의 기능과 UI를 개선합니다.

### 1.2 Background

- **현재 문제**: OCR 기능이 근무표 있는 사용자에만 유용, 공유 캘린더 기능이 색칠/이모지에 한정
- **캘린더 UI**: 직관적이지 않고 작성이 불편
- **필요 기능**: 양쪽 다 비거나 쉬는 날의 데이트 최적일 선정, D-day 카운트다운

### 1.3 Scope

#### 1.1 In Scope

- [ ] 공유 캘린더 기능 확장 (제목, 날짜/시간, 종류, 장소, 메모, 알림, 반복)
- [ ] 일정 자동등록 (기존 근무형태 매핑 → 색상+제목+시간 매핑)
- [ ] OCR → 일반 일정 자동 변환
- [ ] Apple 스타일 캘린더 UI (카드형, 스크롤)
- [ ] 일정 필터/토글 (나만/파트너만/둘 다)
- [ ] 데이트 최적일 선정 (양쪽 다 비거나 쉬는 날)
- [ ] D-day 관리 (연애 시작일 + 다음 데이트까지 D-X일)
- [ ] 커플 기념일 자동 표시 (100일, 1년, 명절, 사용자 정의)
- [ ] 일정 상세 화면 (파트너 일정 읽기전용 + 댓글/채팅)
- [ ] 일정 입력 ('+' 버튼 + 길게 누르기)
- [ ] 야간근무 지원 (시작 > 종료 시간 판단)

#### 1.2 Out of Scope

- [ ] AI 기반 근무 패턴 학습 및 추천 (다음 단계)
- [ ] 복잡한 반복 패턴 (cron 스타일)

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                         │
│                                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  Home       │  │  Calendar   │  │  Schedule   │  │
│  │  Screen     │  │  Screen     │  │  Settings   │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │           │
│         ▼                ▼                ▼           │
│  ┌─────────────────────────────────────────────────┐  │
│  │           Shared Calendar Service               │  │
│  └────────────────────┬────────────────────────────┘  │
└───────────────────────┼─────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Supabase   │  │  OpenAI     │  │  Local      │
│  DB         │  │  OCR        │  │  State      │
└─────────────┘  └─────────────┘  └─────────────┘
```

### 2.2 Data Flow

```
[OCR 이미지 업로드]
    │
    ▼
[OpenAI GPT-4o 분석]
    │
    ▼
[일정 자동등록 매핑 적용]
    │ (색상 → 제목+시간)
    ▼
[캘린더에 일정 자동 등록]
    │
    ▼
[파트너에게 실시간 공유]
```

---

## 3. Data Model

### 3.1 Schedules 테이블 확장

```sql
-- 기존 컬럼 유지
-- id, user_id, couple_id, date, work_type, color_hex, note, is_date, emoji

-- 새로 추가
ALTER TABLE schedules
ADD COLUMN IF NOT EXISTS title VARCHAR(200),
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME,
ADD COLUMN IF NOT EXISTS category VARCHAR(50) CHECK (category IN ('근무', '약속', '여행', '데이트', '기타')),
ADD COLUMN IF NOT EXISTS location VARCHAR(200),
ADD COLUMN IF NOT EXISTS reminder_minutes INT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS repeat_pattern JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_anniversary BOOLEAN DEFAULT FALSE;
```

### 3.2 ColorMappings 테이블 확장

```sql
ALTER TABLE color_mappings
ADD COLUMN IF NOT EXISTS title VARCHAR(200),
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME;
```

### 3.3 AnniversarySettings 테이블

```sql
CREATE TABLE IF NOT EXISTS anniversary_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE,
  anniversary_type VARCHAR(50) NOT NULL, -- '100일', '1년', '화이트데이', '발렌타인', '크리스마스', '사용자정의'
  custom_name VARCHAR(100),
  custom_month INT,
  custom_day INT,
  is_enabled BOOLEAN DEFAULT TRUE,
  reminder_days INT[] DEFAULT ARRAY[7, 1], -- 일주일 전, 당일
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.4 ScheduleComments 테이블

```sql
CREATE TABLE IF NOT EXISTS schedule_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.5 Couples 테이블 확장

```sql
ALTER TABLE couples
ADD COLUMN IF NOT EXISTS started_at DATE;
```

---

## 4. API Specification

### 4.1 Service Layer

| Service | Method | Description |
|---------|--------|-------------|
| ScheduleService | getMonthSchedules | 해당 월의 커플 전체 일정 |
| ScheduleService | addSchedule | 일정 추가 |
| ScheduleService | deleteSchedule | 일정 삭제 |
| ScheduleService | updateSchedule | 일정 수정 |
| ScheduleService | getDateOptimalDays | 데이트 최적일 조회 |
| ScheduleService | getTodaySchedules | 오늘의 일정 요약 |
| ScheduleService | getNextDateSchedule | 다음 데이트 조회 |
| ScheduleService | getDDays | D-day 정보 조회 |
| AnniversaryService | getAnniversaries | 커플 기념일 조회 |
| AnniversaryService | addAnniversary | 기념일 추가 |
| CommentService | getComments | 일정 댓글 조회 |
| CommentService | addComment | 댓글 추가 |

### 4.2 Edge Function

- `ocr-schedule`: OCR로 분석 후 일정 자동등록 매핑 적용
  - 기존 기능 유지 + 매핑된 제목/시간 적용

---

## 5. UI/UX Design

### 5.1 홈 화면

```
┌─────────────────────────────────────────┐
│  👩‍❤️‍👨  연애 125일                      │
├─────────────────────────────────────────┤
│  📅 다음 데이트까지 3일 남음            │
│     강남역 스타벅스 (3월 13일)          │
├─────────────────────────────────────────┤
│  오늘의 일정                           │
│  • 나: 오후 2시 회의                   │
│  • 파트너: 휴일                       │
│  [캘린더로 이동 ▶]                    │
└─────────────────────────────────────────┘
```

- 오늘의 일정 클릭 → 캘린더 해당 날짜로 이동
- 다음 데이트 클릭 → 캘린더 해당 날짜로 이동

### 5.2 캘린더 화면 (Apple 스타일)

```
┌─────────────────────────────────────────┐
│  3월 2026           [+]               │
├─────────────────────────────────────────┤
│  🔄 필터: [나만] [파트너만] [둘 다]   │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────┐    │
│  │  3월 10일 (월)               │    │
│  │  • 정비공 (09:00-18:00)      │    │
│  │  • 팀 회의 (14:00-15:00)     │    │
│  └───────────────────────────────┘    │
│  ┌───────────────────────────────┐    │
│  │  3월 11일 (화)               │    │
│  │  💕 데이트 (19:00-21:00)     │    │
│  └───────────────────────────────┘    │
│  ...                                  │
└─────────────────────────────────────────┘
```

- '+' 플로팅 버튼: 일정 추가
- 날짜 길게 누르기: 일정 추가
- 일정 카드 탭: 상세 화면

### 5.3 일정 자동등록 화면

```
┌─────────────────────────────────────────┐
│  일정 자동등록                        │
├─────────────────────────────────────────┤
│  [+ 새 매핑 추가]                     │
├─────────────────────────────────────────┤
│  색상: [🔴 빨강]                     │
│  제목: [정비공              ] *필수   │
│  시간: [09:00] ~ [18:00] (선택)      │
│       (야간근무: 21:00 ~ 09:00)       │
│  [삭제]                               │
├─────────────────────────────────────────┤
│  [OCR 이미지 업로드]                  │
└─────────────────────────────────────────┘
```

### 5.4 일정 상세 화면

```
┌─────────────────────────────────────────┐
│  정비공 (근무)            [수정] [삭제]│
├─────────────────────────────────────────┤
│  날짜: 2026년 3월 10일 (월)          │
│  시간: 09:00 - 18:00                 │
│  장소: [없음]                         │
│  메모: [없음]                         │
├─────────────────────────────────────────┤
│  댓글                                 │
│  • 파트너: 이번주 정비공 맞아?        │
│  • 나: 응 정비공이야                  │
│  [댓글 작성...]                       │
└─────────────────────────────────────────┘
```

- 파트너의 일정: 읽기전용 (수정/삭제 버튼 숨김)

---

## 6. Implementation Guide

### 6.1 순서

#### 6.1.1 DB 마이그레이션

1. [ ] `supabase/migrations/20260310_schedules_extend.sql` 생성 - Schedules 테이블 확장
2. [ ] `supabase/migrations/20260310_color_mappings_extend.sql` 생성 - ColorMappings 테이블 확장
3. [ ] `supabase/migrations/20260310_anniversary_settings.sql` 생성 - AnniversarySettings 테이블
4. [ ] `supabase/migrations/20260310_schedule_comments.sql` 생성 - ScheduleComments 테이블
5. [ ] `supabase/migrations/20260310_couples_started_at.sql` 생성 - Couples 테이블 확장

#### 6.1.2 데이터 모델

6. [ ] `lib/shared/models/schedule.dart` 수정 - title, startTime, endTime, category, location 등 추가
7. [ ] `lib/shared/models/color_mapping.dart` 수정 - title, startTime, endTime 추가
8. [ ] `lib/shared/models/anniversary_setting.dart` 생성
9. [ ] `lib/shared/models/schedule_comment.dart` 생성
10. [ ] `lib/shared/models/repeat_pattern.dart` 생성

#### 6.1.3 서비스

11. [ ] `lib/features/calendar/services/schedule_service.dart` 확장
12. [ ] `lib/features/calendar/services/anniversary_service.dart` 생성
13. [ ] `lib/features/calendar/services/comment_service.dart` 생성
14. [ ] `lib/features/calendar/services/date_optimal_service.dart` 생성 - 데이트 최적일 선정
15. [ ] `lib/features/home/services/home_service.dart` 생성 - 홈 화면 데이터

#### 6.1.4 UI - 캘린더

16. [ ] `lib/features/calendar/screens/calendar_screen.dart` 수정 - Apple 스타일 UI
17. [ ] `lib/features/calendar/widgets/calendar_card.dart` 생성 - 일정 카드
18. [ ] `lib/features/calendar/widgets/calendar_filter.dart` 생성 - 필터/토글
19. [ ] `lib/features/calendar/widgets/schedule_detail.dart` 생성 - 일정 상세
20. [ ] `lib/features/calendar/widgets/schedule_comments.dart` 생성 - 댓글
21. [ ] `lib/features/calendar/widgets/schedule_add_dialog.dart` 생성 - 일정 추가 다이얼로그

#### 6.1.5 UI - 일정 자동등록

22. [ ] `lib/features/schedule/screens/auto_registration_screen.dart` 생성 - 일정 자동등록 화면
23. [ ] `lib/features/schedule/widgets/color_mapping_card.dart` 생성 - 매핑 카드
24. [ ] `lib/features/schedule/widgets/mapping_add_dialog.dart` 생성 - 매핑 추가 다이얼로그
25. [ ] 기존 `ocr_screen.dart` 수정 - 일정 자동등록 페이지로 이동

#### 6.1.6 UI - 홈

26. [ ] `lib/features/home/screens/home_screen.dart` 생성
27. [ ] `lib/features/home/widgets/dday_widget.dart` 생성
28. [ ] `lib/features/home/widgets/next_date_widget.dart` 생성
29. [ ] `lib/features/home/widgets/today_schedule_widget.dart` 생성

#### 6.1.7 OCR Edge Function

30. [ ] `supabase/functions/ocr-schedule/index.ts` 수정 - 매핑된 제목/시간 적용

---

## 7. Test Plan

| Type | Target | Tool |
|------|--------|------|
| Unit Test | 서비스 로직 | flutter test |
| Integration Test | OCR → 일정 등록 플로우 | flutter test integration |
| E2E Test | 전체 캘린더 기능 | flutter test |

---

## 8. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|----------|------------|
| OCR 분석 오차 | Medium | Medium | 정확도 높은 프롬프트 + 사용자 수정 가능 |
| 실시간 공유 지연 | Low | Low | Supabase Realtime 사용 |
| UI 복잡성 증가 | Medium | Medium | MVP 범위 유지 |
| DB 마이그레이션 오류 | High | Low | 롤백 계획 수립 |

---

## 9. Success Criteria

- [ ] 공유 캘린더 기능 확장 (제목, 시간, 종류, 장소, 메모, 알림, 반복)
- [ ] 일정 자동등록 구현 (색상+제목+시간 매핑)
- [ ] OCR → 일반 일정 자동 변환
- [ ] Apple 스타일 캘린더 UI
- [ ] 데이트 최적일 선정
- [ ] D-day 관리 (연애 시작일 + 다음 데이트)
- [ ] 커플 기념일 자동 표시
- [ ] 일정 상세 + 댓글/채팅
- [ ] 통합 테스트 완료

---

## 10. Next Steps

1. [ ] DB 마이그레이션 적용
2. [ ] 데이터 모델 확장
3. [ ] 서비스 구현
4. [ ] UI 구현 (캘린더, 홈, 일정 자동등록)
5. [ ] OCR Edge Function 수정
6. [ ] 테스트
7. [ ] 배포
