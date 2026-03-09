# Notifications Planning Document

> **Summary**: 파트너 일정 변경 알림, 둘 다 휴무인 날 알림, 데이트 일정 알림 기능
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Author**: Claude
> **Date**: 2026-03-09
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 파트너가 일정을 변경했는지 알 수 없고, 둘 다 휴무인 날을 놓치는 경우가 많아 데이트 기회를 놓침 |
| **Solution** | Supabase Realtime을 활용한 실시간 알림 + 로컬 알림 스케줄링 (둘 다 휴무/데이트 알림) |
| **Function/UX Effect** | 파트너 일정 변경 시 즉시 알림 표시, 둘 다 쉬는 날 자동 알림, 데이트 일정 하루 전/당일 알림 |
| **Core Value** | 커플 간 소통 강화 + 데이트 기회 놓치지 않음 + 교대 근무자 삶의 질 향상 |

---

## 1. Overview

### 1.1 Purpose

교대 근무자와 일반 직장인 커플이 서로의 일정 변화를 실시간으로 인지하고, 둘 다 휴무인 날짜와 데이트 일정을 놓치지 않도록 알림 기능을 제공합니다.

### 1.2 Background

- 현재 파트너가 일정을 추가/삭제/수정하면 앱을 새로고침해야 알 수 있음
- 교대 근무자는 매달 근무표가 바뀌어 파트너의 일정 변화 추적 어려움
- 둘 다 휴무인 날을 모르고 데이트를 놓치는 경우 빈번

### 1.3 Related Documents

- Requirements: N/A
- References: Supabase Realtime Documentation, Flutter Local Notifications Package

---

## 2. Scope

### 2.1 In Scope

- [ ] 파트너 일정 추가 알림 (실시간)
- [ ] 파트너 일정 삭제 알림 (실시간)
- [ ] 파트너 일정 수정 알림 (실시간)
- [ ] 둘 다 휴무인 날 자동 알림 (오전 9시)
- [ ] 데이트 일정 하루 전 알림 (오전 9시)
- [ ] 데이트 일정 당일 알림 (오전 9시)
- [ ] 알림 설정 화면 (각 알림 켜기/끄기)
- [ ] 알림 히스토리 목록

### 2.2 Out of Scope

- 그룹 채팅 기능
- 채팅 알림
- 마케팅/프로모션 알림

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 파트너가 일정을 추가하면 내 앱에 실시간 알림 표시 | High | Pending |
| FR-02 | 파트너가 일정을 삭제하면 내 앱에 실시간 알림 표시 | High | Pending |
| FR-03 | 파트너가 일정을 수정하면 내 앱에 실시간 알림 표시 | High | Pending |
| FR-04 | 매일 오전 9시에 오늘 둘 다 휴무인지 확인 후 알림 | Medium | Pending |
| FR-05 | 데이트 일정 하루 전 오전 9시에 알림 | Medium | Pending |
| FR-06 | 데이트 일정 당일 오전 9시에 알림 | Medium | Pending |
| FR-07 | 각 알림 타입별로 켜기/끄기 설정 가능 | Medium | Pending |
| FR-08 | 최근 알림 목록 표시 | Low | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| Performance | 실시간 알림 3초 이내 도착 | Supabase Realtime Latency 측정 |
| Security | 알림 내용에 민감 정보 포함하지 않음 | Code Review |
| Accessibility | 알림 텍스트 이해하기 쉽게 작성 | UX Review |
| Privacy | 파트너만 나의 일정 변경 알림 수신 가능 | Supabase RLS 검증 |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] All functional requirements implemented
- [ ] 알림 설정 화면 구현 완료
- [ ] 알림 히스토리 화면 구현 완료
- [ ] 실시간 알림 동작 테스트 통과
- [ ] 로컬 알림 스케줄링 동작 테스트 통과

### 4.2 Quality Criteria

- [ ] 알림 누락 없음
- [ ] 알림 중복 발생하지 않음
- [ ] 알림 설정 저장/로드 정상 동작

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 백그라운드에서 실시간 알림 수신 실패 | High | Medium | flutter_local_notifications로 대응 |
| 로컬 알림 권한 거부 시 기능 불가 | Medium | Low | 권한 설정 안내 화면 추가 |
| 배터리 소모 증가 | Medium | Medium | 알림 최적화 + 설정으로 제어 가능 |

---

## 6. Architecture Considerations

### 6.1 Project Level Selection

| Level | Characteristics | Recommended For | Selected |
|-------|-----------------|-----------------|:--------:|
| **Starter** | Simple structure (`components/`, `lib/`, `types/`) | Static sites, portfolios, landing pages | ☐ |
| **Dynamic** | Feature-based modules, BaaS integration (bkend.ai) | Web apps with backend, SaaS MVPs, fullstack apps | ☑ |
| **Enterprise** | Strict layer separation, DI, microservices | High-traffic systems, complex architectures | ☐ |

**Selected Level**: Dynamic (기존 프로젝트 구조 유지)

### 6.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| Realtime Communication | Supabase Realtime / WebSocket / FCM | Supabase Realtime | 기존 Supabase 사용 중, 설정 간단 |
| Local Notifications | flutter_local_notifications /awesome_notifications | flutter_local_notifications | Flutter 표준 패키지 |
| State Management | Provider / Riverpod / GetX | Provider | 기존 프로젝트에서 사용 |
| Notification Storage | Supabase / Local DB | Local DB (SharedPreferences) | 간단한 설정 저장 |

### 6.3 Clean Architecture Approach

```
Selected Level: Dynamic

Folder Structure Preview:
┌─────────────────────────────────────────────────────┐
│ Dynamic:                                            │
│   lib/features/                                     │
│     notifications/                                    │
│       screens/                                       │
│         notification_settings_screen.dart                 │
│         notification_history_screen.dart                  │
│       services/                                      │
│         notification_service.dart                        │
│       models/                                        │
│         notification.dart                              │
│       widgets/                                       │
│         notification_card.dart                          │
│   core/                                             │
│     notification_manager.dart                           │
└─────────────────────────────────────────────────────┘
```

---

## 7. Convention Prerequisites

### 7.1 Existing Project Conventions

- [x] Flutter 프로젝트 (기존 구조 확인)
- [ ] notification 패키지 추가 필요

### 7.2 Conventions to Define/Verify

| Category | Current State | To Define | Priority |
|----------|---------------|-----------|:--------:|
| **Naming** | exists (snake_case) | 유지 | High |
| **Folder structure** | exists (features/ 기반) | notifications 폴더 추가 | High |
| **State Management** | Provider | Provider 사용 | High |

### 7.3 Environment Variables Needed

| Variable | Purpose | Scope | To Be Created |
|----------|---------|-------|:-------------:|
| N/A | N/A | N/A | ☐ |

### 7.4 Pipeline Integration

Flutter 프로젝트로 9-phase Pipeline 불필요

---

## 8. Next Steps

1. [ ] Design document 작성 (`notifications.design.md`)
2. [ ] 팀 리뷰 및 승인
3. [ ] 구현 시작

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-09 | Initial draft | Claude |
