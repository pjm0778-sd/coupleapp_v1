# UI Redesign (Deux Design System) — Gap Analysis

**Date**: 2026-03-20
**Feature**: ui-redesign
**Match Rate**: 89%
**Status**: WARN (iteration recommended)

---

## Overall Scores

| Category | Score | Status |
|----------|:-----:|:------:|
| Design System (theme.dart) | 100% | ✅ PASS |
| Auth Screens | 92% | ⚠️ WARN |
| Home Screens & Widgets | 90% | ✅ PASS |
| Calendar Screens & Widgets | 62% | ❌ FAIL |
| Onboarding Screens | 75% | ⚠️ WARN |
| Midpoint Screens & Widgets | 100% | ✅ PASS |
| Notification Screens | 100% | ✅ PASS |
| Settings Screen | 92% | ⚠️ WARN |
| Transport Screens | 83% | ⚠️ WARN |
| Couple Connect Screen | 100% | ✅ PASS |
| Auto Registration Screen | 80% | ⚠️ WARN |
| **Overall** | **89%** | **⚠️ WARN** |

---

## Gaps (Design O, Implementation X) — 12개

| # | 항목 | 파일:라인 | 설명 |
|---|------|-----------|------|
| 1 | 온보딩 progress dots → Gold | `onboarding_progress.dart:21` | Navy 바 → Gold 도트(활성 20px / 비활성 8px) |
| 2 | 캘린더 기념일 색상 → Gold | `calendar_screen.dart:175,198,231` | `#FF4081` → `AppTheme.accent` |
| 3 | 캘린더 overflow 텍스트 → textTertiary | `calendar_screen.dart:887` | `textSecondary` → `textTertiary` |
| 4 | 캘린더 OCR 아이콘 → warning | `calendar_screen.dart:617` | `Colors.orangeAccent` → `AppTheme.warning` |
| 5 | 캘린더 삭제 아이콘 → error | `calendar_screen.dart:623` | `Colors.redAccent` → `AppTheme.error` |
| 6 | DayDetailSheet radius 28 | `day_detail_sheet.dart:99` | `circular(20)` → `circular(28)` |
| 7 | DayDetailSheet 기념일 배너 → Gold | `day_detail_sheet.dart:264-267` | `Color(0xFFFF4081)` → `AppTheme.accent` |
| 8 | 일정 추가 색상 선택 Gold 테두리 | `schedule_add_sheet.dart:391` | `textPrimary` → `AppTheme.accent` |
| 9 | 자동등록 TabBar indicator → Gold | `auto_registration_screen.dart:273` | `AppTheme.primary` → `AppTheme.accent` |
| 10 | 교통편 카드 화살표 → Gold | `transport_preview_card.dart:89` | `textSecondary` → `AppTheme.accent` |
| 11 | 로그인 TextButton → Gold | `login_screen.dart:184` | `AppTheme.primary` → `AppTheme.accent` |
| 12 | 설정 "회원탈퇴" → textTertiary | `settings_screen.dart` | `Colors.grey` → `AppTheme.textTertiary` |

---

## Added Features (구현에만 있음, 허용)

| # | 항목 | 파일 | 설명 |
|---|------|------|------|
| 1 | D-day 공휴일 배너 | `dday_widget.dart` | UX 향상 — 허용 |
| 2 | D-day 다음 데이트 D-N | `dday_widget.dart` | UX 향상 — 허용 |
| 3 | 역 검색 시트 지역 탭 | `transport_search_screen.dart` | 필요 기능 — 허용 |

---

## 수정 우선순위

### P0 — 즉시 수정 (→ 94% 달성)
1. `calendar_screen.dart`: `#FF4081` → `AppTheme.accent` (기념일 색상 전체)
2. `calendar_screen.dart`: `Colors.orangeAccent` → `AppTheme.warning`, `Colors.redAccent` → `AppTheme.error`
3. `onboarding_progress.dart`: Gold 도트 스타일로 변경

### P1 — 중간 우선순위
4. `login_screen.dart`: TextButton → accent
5. `auto_registration_screen.dart`: TabBar indicator → accent
6. `transport_preview_card.dart`: 화살표 → accent
7. `schedule_add_sheet.dart`: 색상 선택 border → accent
8. `settings_screen.dart`: 회원탈퇴 → textTertiary

### P2 — 낮은 우선순위
9. `day_detail_sheet.dart`: radius 20 → 28
10. `day_detail_sheet.dart`: 기념일 배너 → accent
11. `calendar_screen.dart`: overflow → textTertiary
