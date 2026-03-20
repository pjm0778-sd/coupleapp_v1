# Notifications Design Document

> **Summary**: 파트너 일정 변경 실시간 알림 및 스케줄링 알림 시스템 설계
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Author**: Claude
> **Date**: 2026-03-09
> **Status**: Draft
> **Planning Doc**: [notifications.plan.md](../01-plan/features/notifications.plan.md)

---

## 1. Overview

### 1.1 Design Goals

- Supabase Realtime을 활용하여 파트너 일정 변경을 3초 이내에 알림
- flutter_local_notifications로 로컬 알림 스케줄링 구현
- 알림 설정으로 사용자 제어 가능하도록 설계
- 배터리 소모 최소화

### 1.2 Design Principles

- **Single Responsibility**: 각 모듈(Realtime, Local Notification, Settings)이 단일 책임 수행
- **Extensible**: 새로운 알림 타입 추가 시 쉽게 확장 가능
- **Privacy**: 파트너만 실시간 알림 수신 가능 (Supabase RLS로 보장)

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App                             │
├─────────────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐     ┌──────────────┐                │
│  │ Notification │────▶│ Notification │                │
│  │   Service    │     │  Manager    │                │
│  └──────────────┘     └──────────────┘                │
│         │                     │                           │
│         │                     │                           │
│         ▼                     ▼                           │
│  ┌──────────────┐     ┌──────────────┐                │
│  │   Realtime   │     │  Local       │                │
│  │  Listener    │     │ Notification │                │
│  └──────────────┘     │  Scheduler   │                │
│         │             └──────────────┘                │
│         │                     │                           │
└─────────┼─────────────────────┼───────────────────────────┘
          │                     │
          ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│              Supabase                               │
│  ┌─────────────┐     ┌─────────────┐             │
│  │ Realtime    │────▶│ schedules   │             │
│  │  Service    │     │   table     │             │
│  └─────────────┘     └─────────────┘             │
└───────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
[파트너 일정 변경]
    │
    ▼
Supabase DB INSERT/UPDATE/DELETE
    │
    ▼
Supabase Realtime Event
    │
    ▼
[내 앱 Realtime Listener 수신]
    │
    ▼
Notification Service → Local Notification 표시
```

```
[매일 오전 9시]
    │
    ▼
Notification Scheduler
    │
    ▼
오늘 일정 확인 (둘 다 휴무? 데이트?)
    │
    ▼
Local Notification 표시
```

### 2.3 Dependencies

| Component | Depends On | Purpose |
|-----------|-----------|---------|
| NotificationService | Supabase Realtime, flutter_local_notifications | 알림 관리 |
| NotificationManager | NotificationService | 전역 알림 상태 관리 |
| NotificationSettingsScreen | NotificationManager | 알림 설정 UI |
| NotificationHistoryScreen | NotificationManager | 알림 히스토리 UI |

---

## 3. Data Model

### 3.1 Entity Definition

```dart
// lib/features/notifications/models/notification.dart
class Notification {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;

  Notification({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      type: NotificationType.fromString(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type.toString(),
    };
  }
}

enum NotificationType {
  scheduleAdded,
  scheduleDeleted,
  scheduleUpdated,
  bothOff,
  dateBefore,
  dateToday,
}

extension NotificationTypeExtension on NotificationType {
  String toString() {
    switch (this) {
      case NotificationType.scheduleAdded:
        return 'schedule_added';
      case NotificationType.scheduleDeleted:
        return 'schedule_deleted';
      case NotificationType.scheduleUpdated:
        return 'schedule_updated';
      case NotificationType.bothOff:
        return 'both_off';
      case NotificationType.dateBefore:
        return 'date_before';
      case NotificationType.dateToday:
        return 'date_today';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'schedule_added':
        return NotificationType.scheduleAdded;
      case 'schedule_deleted':
        return NotificationType.scheduleDeleted;
      case 'schedule_updated':
        return NotificationType.scheduleUpdated;
      case 'both_off':
        return NotificationType.bothOff;
      case 'date_before':
        return NotificationType.dateBefore;
      case 'date_today':
        return NotificationType.dateToday;
      default:
        return NotificationType.scheduleAdded;
    }
  }
}
```

```dart
// lib/features/notifications/models/notification_settings.dart
class NotificationSettings {
  final bool scheduleAdded;
  final bool scheduleDeleted;
  final bool scheduleUpdated;
  final bool bothOff;
  final bool dateBefore;
  final bool dateToday;

  NotificationSettings({
    this.scheduleAdded = true,
    this.scheduleDeleted = true,
    this.scheduleUpdated = true,
    this.bothOff = true,
    this.dateBefore = true,
    this.dateToday = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      scheduleAdded: json['schedule_added'] as bool? ?? true,
      scheduleDeleted: json['schedule_deleted'] as bool? ?? true,
      scheduleUpdated: json['schedule_updated'] as bool? ?? true,
      bothOff: json['both_off'] as bool? ?? true,
      dateBefore: json['date_before'] as bool? ?? true,
      dateToday: json['date_today'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_added': scheduleAdded,
      'schedule_deleted': scheduleDeleted,
      'schedule_updated': scheduleUpdated,
      'both_off': bothOff,
      'date_before': dateBefore,
      'date_today': dateToday,
    };
  }
}
```

### 3.2 Entity Relationships

```
[Notification] N ──── 1 [NotificationType]
[Notification] N ──── 1 [NotificationSettings]
```

---

## 4. API Specification

### 4.1 Supabase Realtime Setup

schedules 테이블에 Realtime 활성화 필요:

```sql
-- Supabase Dashboard에서 실행
ALTER PUBLICATION supabase_realtime ADD TABLE schedules;
```

### 4.2 Realtime Event Types

| Event | Trigger | Payload |
|--------|----------|----------|
| INSERT | 파트너가 일정 추가 | {new_record} |
| UPDATE | 파트너가 일정 수정 | {old_record, new_record} |
| DELETE | 파트너가 일정 삭제 | {old_record} |

### 4.3 Filter 설정

파트너의 일정만 수신하도록 필터 적용:

```dart
final subscription = supabase
    .channel('schedules')
    .on(
      RealtimeListenTypes.insert,
      filter: 'user_id=eq.{partnerUserId}',
      callback: (payload) => _handleInsert(payload),
    )
    .subscribe();
```

---

## 5. UI/UX Design

### 5.1 Screen Layout - Notification Settings

```
┌────────────────────────────────────┐
│  알림 설정                     │
├────────────────────────────────────┤
│                                │
│  ☑ 파트너 일정 추가 알림     │
│  ☑ 파트너 일정 삭제 알림     │
│  ☑ 파트너 일정 수정 알림     │
│                                │
│  ─────────────────────            │
│                                │
│  ☑ 둘 다 휴무 알림          │
│  ☑ 데이트 하루 전 알림       │
│  ☑ 데이트 당일 알림         │
│                                │
│  ─────────────────────            │
│                                │
│  [모두 켜기]  [모두 끄기]   │
└────────────────────────────────────┘
```

### 5.2 Screen Layout - Notification History

```
┌────────────────────────────────────┐
│  알림 [N개 안읽음]          │
├────────────────────────────────────┤
│                                │
│  [오늘]  [최근 7일]         │
│                                │
│  ┌───────────────────────────┐   │
│  │ 🔵 파트너가 일정을    │   │
│  │     추가했어요             │   │
│  │ 3월 9일 14:30          │   │
│  └───────────────────────────┘   │
│                                │
│  ┌───────────────────────────┐   │
│  │ ❤️ 오늘 둘 다 쉬는    │   │
│  │     날이에요!             │   │
│  │ 3월 9일 09:00          │   │
│  └───────────────────────────┘   │
│                                │
│  [모두 읽음으로 표시]        │
└────────────────────────────────────┘
```

### 5.3 User Flow

```
로그인
    │
    ▼
[Notification Manager 초기화]
    │
    ├─▶ Realtime 구독
    │
    ├─▶ Local Notification 권한 요청
    │
    └─▶ 스케줄링 시작 (매일 오전 9시)
    │
    ▼
[앱 사용 중 알림 수신]
    │
    ▼
[설정 화면에서 알림 ON/OFF]
```

### 5.4 Component List

| Component | Location | Responsibility |
|-----------|----------|----------------|
| NotificationManager | lib/core/notification_manager.dart | 전역 알림 상태 관리, 초기화 |
| NotificationService | lib/features/notifications/services/notification_service.dart | Realtime 리스닝, 로컬 알림 발송 |
| NotificationSettingsScreen | lib/features/notifications/screens/notification_settings_screen.dart | 알림 설정 UI |
| NotificationHistoryScreen | lib/features/notifications/screens/notification_history_screen.dart | 알림 히스토리 UI |
| NotificationCard | lib/features/notifications/widgets/notification_card.dart | 알림 카드 위젯 |
| NotificationSettingsModel | lib/features/notifications/models/notification_settings.dart | 알림 설정 모델 |
| NotificationModel | lib/features/notifications/models/notification.dart | 알림 모델 |

---

## 6. Error Handling

### 6.1 Error Code Definition

| Code | Message | Cause | Handling |
|------|---------|-------|----------|
| NOTI_001 | Realtime 구독 실패 | 네트워크 오류 | 재시도, 네트워크 연결 확인 안내 |
| NOTI_002 | Local Notification 권한 거부 | 사용자 거부 | 설정 안내, 알림 기능 비활성화 |
| NOTI_003 | 스케줄링 설정 실패 | OS 권한 문제 | 배터리 최적화 설정 안내 |

### 6.2 Error Response Format

```dart
// 알림 발송 실패 시 로깅 및 사용자 안내
void _handleNotificationError(String error) {
  debugPrint('Notification error: $error');
  // 사용자에게 비침습적 안내 (선택적)
}
```

---

## 7. Security Considerations

- [x] **RLS 적용**: 파트너만 실시간 알림 수신 (Supabase RLS)
- [x] **알림 내용 보안**: 민감 정보 포함하지 않음
- [x] **권한 관리**: Local Notification 권한 명시적 요청

---

## 8. Test Plan

### 8.1 Test Scope

| Type | Target | Tool |
|------|--------|------|
| Unit Test | NotificationService, NotificationManager | flutter test |
| Integration Test | Realtime 연동 | flutter test integration |
| Manual Test | 알림 UI/UX | 실기기 테스트 |

### 8.2 Test Cases (Key)

- [ ] 파트너가 일정을 추가하면 내 앱에 알림 표시
- [ ] 파트너가 일정을 삭제하면 내 앱에 알림 표시
- [ ] 파트너가 일정을 수정하면 내 앱에 알림 표시
- [ ] 알림 설정 OFF 시 해당 알림 수신 안 함
- [ ] 매일 오전 9시 둘 다 휴무 확인 알림
- [ ] 데이트 일정 하루 전 알림
- [ ] 데이트 일정 당일 알림
- [ ] 알림 히스토리 정상 표시

---

## 9. Clean Architecture

### 9.1 Layer Structure

| Layer | Responsibility | Location |
|-------|---------------|----------|
| **Presentation** | UI components, screens | `lib/features/notifications/screens/`, `widgets/` |
| **Application** | Services, business logic | `lib/features/notifications/services/` |
| **Domain** | Models, types | `lib/features/notifications/models/` |
| **Infrastructure** | Supabase, notification plugins | `lib/core/`, `shared/` |

### 9.2 Dependency Rules

```
┌─────────────────────────────────────────────────────────────┐
│                    Dependency Direction                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Presentation ──→ Application ──→ Domain ←── Infrastructure│
│                          │                                  │
│                          └──→ Infrastructure                │
│                                                             │
│   Rule: Inner layers MUST NOT depend on outer layers        │
│         Domain is independent (no external dependencies)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 9.3 This Feature's Layer Assignment

| Component | Layer | Location |
|-----------|-------|----------|
| NotificationSettingsScreen | Presentation | `lib/features/notifications/screens/` |
| NotificationHistoryScreen | Presentation | `lib/features/notifications/screens/` |
| NotificationCard | Presentation | `lib/features/notifications/widgets/` |
| NotificationService | Application | `lib/features/notifications/services/` |
| NotificationSettingsModel | Domain | `lib/features/notifications/models/` |
| NotificationModel | Domain | `lib/features/notifications/models/` |
| NotificationManager | Infrastructure | `lib/core/` |

---

## 10. Coding Convention Reference

### 10.1 Naming Conventions (Flutter)

| Target | Rule | Example |
|--------|------|---------|
| Classes | PascalCase | `NotificationService`, `NotificationCard` |
| Variables | camelCase | `userId`, `scheduleList` |
| Constants | UPPER_SNAKE_CASE | `NOTIFICATION_CHANNEL_ID`, `SCHEDULES_TABLE` |
| Enums | PascalCase | `NotificationType` |
| Files | snake_case.dart | `notification_service.dart`, `notification_settings_screen.dart` |
| Folders | snake_case | `notifications/`, `services/`, `models/` |

### 10.2 Import Order (Dart)

```dart
// 1. Dart core
import 'dart:async';

// 2. Flutter packages
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 3. Third-party packages
import 'package:supabase_flutter/supabase_flutter.dart';

// 4. Project imports (core first)
import '../../../core/supabase_client.dart';

// 5. Feature imports
import '../models/notification.dart';
import '../models/notification_settings.dart';
```

### 10.3 This Feature's Conventions

| Item | Convention Applied |
|------|-------------------|
| Component naming | PascalCase (Flutter standard) |
| File organization | features/notifications/{screens,services,models,widgets}/ |
| State management | Provider (기존 프로젝트 유지) |
| Error handling | debugPrint 로깅 + 사용자 친숙적 안내 |

---

## 11. Implementation Guide

### 11.1 File Structure

```
lib/
├── core/
│   └── notification_manager.dart          # 전역 알림 관리자
├── features/
│   └── notifications/
│       ├── screens/
│       │   ├── notification_settings_screen.dart
│       │   └── notification_history_screen.dart
│       ├── services/
│       │   └── notification_service.dart
│       ├── models/
│       │   ├── notification.dart
│       │   └── notification_settings.dart
│       └── widgets/
│           └── notification_card.dart
└── main.dart                                  # 초기화 추가
```

### 11.2 Implementation Order

1. [ ] 패키지 의존성 추가 (flutter_local_notifications)
2. [ ] 모델 정의 (Notification, NotificationSettings, NotificationType)
3. [ ] NotificationManager 구현 (전역 상태 관리)
4. [ ] NotificationService 구현 (Realtime + Local Notification)
5. [ ] NotificationSettingsScreen 구현
6. [ ] NotificationHistoryScreen 구현
7. [ ] 알림 아이콘/리소스 추가
8. [ ] Supabase Realtime 활성화 (schedules 테이블)
9. [ ] 통합 테스트

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-09 | Initial draft | Claude |
