# 근무표 AI 자동 생성 서비스 설계

> **Feature**: AI 기반 근무표 자동 생성 및 스케줄링
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Date**: 2026-03-09

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 교대 근무자와 일반 직장인 커플이 매일 스케줄을 하나하나 누르면서 근무표를 직접 작성하는 것은 불편하고 비효율적이 적음 |
| **Solution** | AI가 달력을 분석하여 최적의 근무 패턴 파악하고, 인터페이스로 쉽게 근무표 선택 및 저장 기능을 제공 |
| **Function/UX Effect** | 클릭 몇 번으로 쉬고 테스트로 근무표를 완성 | 캘린더 기반으로 최적 스케줄링 |
| **Core Value** | 커플 간 효율적화 + 데이트 기회 놓치지 않음 (최적 50% 효율) |

---

## 1. Overview

### 1.1 Purpose

AI가 수집한 일정 데이터를 분석하여 커플이의 근무 패턴을 파악하고, 사용자가 캘린더 + 스케줄 템플릿을 선택할 수 있도록 근무표를 자동으로 추천합니다. 또한 번 반복되는 근무표를 선택하여 여러 날짜에 일괄 적용할 수 있게 만듭니다.

### 1.2 Background

- **현재 문제**: 사용자가 매월 근무표를 직접 작성해야 함
- 교대 근무자: 달력이 매달 달라도 빡틀림, 일반 직장인 경우 일정이 예측 불가
- 사용자 인력: 직장 근무형, 근무 패턴이 다름
- 기존 UI: OCR 화면에서만 일정 생성 가능

### 1.3 Scope

#### 1.1 In Scope

- [ ] 달력 분석 및 패턴 파악
- [ ] 인터페이스: 근무표 선택 및 저장
- [ ] 단순 계산
- [ ] 단순 템플릿 (선택된 날짜 반복)
- [ ] 캘린더 UI에서 근무표 선택

#### 1.2 Out of Scope

- [ ] 근무표 자동 생성 (다음 단계)
- [ ] 복잡 알림: 각종 근무 패턴 학습 (시간 소요)

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────┐     ┌──────────────┐
│  Flutter App   │                │   Supabase DB      │
│              │                │                  │
│  └──────┬─┘     └────────────────┘
│  AI 근무표  │────▶│   근무표 생성   │
└──────────────────┘
```

### 2.2 Data Flow

```
User Input
    │
    ▼
    ▼
[캘린더 UI 선택]
    │
    ▼
[근무표 저장]
    │
    ▼
[근무표 적용 → 스케줄링 등록]
```

---

## 3. Data Model

### 3.1 SchedulePattern 모델

```dart
class SchedulePattern {
  final String patternType; // 'daily', 'shift_3', 'shift_4', '2day_2off', 'custom'
  final List<DateTime> dates;       // 해당 패턴이 적용되는 날짜들
  final String? workType;     // 근무형태 (예: 나이트, 휴무)
  final String? color;        // 색상

  SchedulePattern({
    required this.patternType,
    required this.dates,
    this.workType,
    this.color,
  });

  // JSON 변환
  factory SchedulePattern.fromJson(Map<String, dynamic> json) {
    return SchedulePattern(
      patternType: json['pattern_type'] as String,
      dates: (json['dates'] as List<DateTime>)
          .map((d) => DateTime.parse(d as String))
          .toList(),
      workType: json['work_type'] as String?,
      color: json['color_hex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pattern_type': patternType,
      'dates': dates.map((d) => d.toIso8601String()).toList(),
      'work_type': workType,
      'color_hex': color,
    };
  }
}
```

### 3.2 PatternHistory 모델

```dart
class PatternHistory {
  final List<SchedulePattern> patterns = [];

  void add(SchedulePattern pattern) {
    patterns.add(pattern);
  }

  // 가장 빈도 패턴 찾기 (최근 3개월)
  SchedulePattern findMostFrequent(DateTime targetMonth) {
    // targetMonth가 포함된 월의 데이터 중 가장 빈도 패턴 찾기
  }
}
```

---

## 4. API Specification

### 4.1 Service Layer

| Service | Endpoint | Description |
|---------|--------|-------------|
| PatternAnalysisService | POST /patterns | AI 패턴 분석 요청 |
| PatternRecommendationService | GET /patterns | 추천 패턴 반환 |
| SchedulePatternService | POST /patterns | 근무표 저장 |

### 4.2 Edge Function 구현 (다음 단계)

Supabase Edge Function: `pattern-analysis` 생성

---

## 5. UI/UX Design

### 5.1 인터페이스 구조

```
┌─────────────────────────────┐
│  캘린더                          │
│  └─────────────────────────────┘
│                                    │
│  [+] 패턴 추가          │
│  [▼] 달력 선택          │
│  [AI 추천 보기          │
│                                    │
│  [적용 완료] [취소]          │
└─────────────────────────────┘
```

### 5.2 근무표 카드

| 날짜 | 근무형태 | 색상 |
|------|------|-------|
| 나이트 | 🌙 나이트 | 파란색 |
| 휴무 | 🟢 주간 근무 | 연두 주간 |
| 데이트 | 💕 데이트 | 분홍색 |
| 막스케줄 | 🚑 연 2주 1근무 2주 2오프 |

---

## 6. Implementation Guide

### 6.1 순서

1. [ ] `lib/features/schedule/services/pattern_analysis_service.dart` 생성 - 패턴 분석 서비스
2. [ ] `lib/features/schedule/services/pattern_recommendation_service.dart` 생성 - 추천 서비스
3. [ ] `lib/features/schedule/services/pattern_history_service.dart` 생성 - 패턴 히스토리 서비스
4. [ ] `lib/features/schedule/models/schedule_pattern.dart` 생성 - 패턴 모델
5. [ ] `lib/features/schedule/models/pattern_history.dart` 생성 - 히스토리 모델
6. [ ] `lib/features/schedule/widgets/pattern_selector.dart` 생성 - 패턴 선택 위젯
7. [ ] `lib/features/schedule/widgets/schedule_card.dart` 생성 - 선택된 패턴 카드
8. [ ] OCR 화면에 패턴 선택 및 적용 버튼 추가

### 6.2 순서

1. [ ] Supabase Edge Function `pattern-analysis` 생성
2. [ ] OCR 화면 UI 수정
3. [ ] 테스트

---

## 7. Test Plan

| Type | Target | Tool |
|------|--------|------|--------|
| Unit Test | 패턴 분석 로직 | flutter test |
| Integration Test | 전체 플로우 테스트 | flutter test integration |
| E2E Test | 실제 근무표 자동 생성 | flutter test |

---

## 8. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|----------|------------|
| AI 분석 오차 가능 | Medium | Medium | 여러 패턴 중 최적 찾기 로직 개선 |
| 과도 추천 오류 가능 | Medium | Low | 단순 적용 시 데이터 오없는 패턴 생성 위험 |
| UI 복잡성 날짜 가능 | Low | 캘린더 UI 적용 제어 |
| 저장 데이터 손실 | Low | Supabase에 패턴 저장 |

---

## 9. Success Criteria

- [ ] 패턴 분석 기능 구현
- [ ] 캘린더 UI 구현
- [ ] OCR 화면 패턴 적용
- [ ] 근무표 자동 생성
- [ ] 통합 테스트 완료

---

## 10. Next Steps

1. [ ] 인터페이스 구현
2. [ ] Supabase Edge Function 배포
3. [ ] 테스트
4. [ ] 배포
