# UI Redesign Plan — 커플듀티 전면 리디자인

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | ui-redesign |
| 시작일 | 2026-03-20 |
| 목표 | 앱 전체 UI를 모던 & 세련된 Navy + Gold 테마로 전면 교체 |

### Value Delivered (4-Perspective)

| 관점 | 내용 |
|------|------|
| Problem | 현재 다크그레이+살구핑크 조합이 커플앱 특성에 비해 감성이 부족하고 고급스럽지 않음 |
| Solution | Navy(#1A2A4A) + Gold(#C9A84C) 팔레트 + Playfair Display 폰트로 모던하고 세련된 디자인 시스템 구축 |
| Function UX Effect | 로그인부터 홈, 캘린더, 중간지점 등 모든 화면의 색상/레이아웃/컴포넌트를 일관된 기준으로 교체 |
| Core Value | 커플이 사용하고 싶어지는, 고급스럽고 감성적인 앱 경험 제공 |

---

## 1. 배경 및 목표

### 현재 상태
- Primary: `#2C2C2C` (다크그레이), Accent: `#E8A598` (살구핑크)
- 폰트: Noto Sans KR 단일 사용
- 카드: border 기반, elevation 없음
- 전반적으로 실용적이지만 감성적 매력 부족

### 목표 상태
- Primary: `#1A2A4A` (딥 네이비), Accent: `#C9A84C` (소프트 골드)
- 폰트: Noto Sans KR + Playfair Display (강조용)
- 카드: shadow 기반 (border 제거), 더 넓은 radius
- 커플앱다운 따뜻하고 고급스러운 느낌

---

## 2. 변경 범위

### 필수 변경 (전면 교체)
- [ ] `lib/core/theme.dart` — 컬러/타이포/컴포넌트 테마 전체
- [ ] `lib/features/auth/screens/login_screen.dart`
- [ ] `lib/features/auth/screens/signup_screen.dart`
- [ ] `lib/features/onboarding/` — 온보딩 4단계 전체
- [ ] `lib/main.dart` — BottomNavigationBar 스타일
- [ ] `lib/features/home/screens/home_screen.dart`
- [ ] `lib/features/home/widgets/` — dday, next_date, today_schedule, transport_preview
- [ ] `lib/features/calendar/screens/calendar_screen.dart`
- [ ] `lib/features/midpoint/screens/` + widgets
- [ ] `lib/features/transport/screens/`
- [ ] `lib/features/settings/screens/settings_screen.dart`
- [ ] `lib/features/notifications/screens/`
- [ ] `lib/features/couple/screens/`

### 간접 반영 (테마 변경으로 자동 적용)
- ElevatedButton, OutlinedButton, InputDecoration
- Card, AppBar, Divider

---

## 3. 구현 우선순위

| 순서 | 작업 | 예상 영향범위 |
|------|------|-------------|
| 1 | theme.dart 전면 교체 | 전체 앱 자동 반영 |
| 2 | 로그인/회원가입 화면 | 첫인상 |
| 3 | 홈 화면 레이아웃 재설계 | 핵심 UX |
| 4 | BottomNavBar 스타일 | 전역 네비게이션 |
| 5 | 온보딩 화면 | 신규 유저 경험 |
| 6 | 캘린더 화면 | 핵심 기능 |
| 7 | 중간지점/교통 화면 | 기능 화면 |
| 8 | 설정/알림 화면 | 보조 화면 |

---

## 4. 제약 사항

- 기능 로직 변경 없음 (UI만 변경)
- Supabase, 서비스 레이어 코드 불변
- 기존 schedule colors (20색) 유지, 채도만 소폭 조정
- Google Fonts 패키지에 Playfair Display 추가 필요
