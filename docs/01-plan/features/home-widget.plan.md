# Plan: home-widget

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | home-widget |
| 시작일 | 2026-03-23 |
| 목표 | iOS / Android 홈 화면 위젯 |

### Value Delivered (4-Perspective)

| 관점 | 내용 |
|------|------|
| **Problem** | 앱을 열지 않아도 D+일수, 다음 데이트, 보고 싶은 일수를 확인하고 싶음 |
| **Solution** | iOS WidgetKit + Android AppWidget으로 홈 화면에 커플 정보 위젯 제공 |
| **Function UX Effect** | 홈 화면에서 즉시 확인 → 앱 진입 빈도 증가, 감성적 연결감 강화 |
| **Core Value** | 앱 밖에서도 연인과 연결되어 있다는 느낌 제공 |

---

## 1. 기능 개요

### 위젯 크기별 표시 데이터

| 크기 | Android | iOS | 표시 내용 |
|------|---------|-----|---------|
| Small (2×2) | 지원 | 지원 | D+N · 오늘 나의 일정 · 오늘 파트너 일정 |
| Medium (4×2) | 지원 | 지원 | D+N · 오늘 나의 일정 · 오늘 파트너 일정 · 내 지역 날씨 · 파트너 지역 날씨 · 다음 데이트 D-N |

### 데이터 항목 상세

| 데이터 키 | 설명 | 출처 |
|-----------|------|------|
| `d_days` | 사귄 지 N일 | couples.started_at |
| `partner_name` | 파트너 닉네임 | profiles |
| `my_schedule` | 오늘 내 일정 첫 번째 (없으면 "여유로운 하루") | schedules |
| `partner_schedule` | 오늘 파트너 일정 첫 번째 (없으면 "여유로운 하루") | schedules |
| `my_weather` | 내 지역 날씨 (도시명 + 기온 + 아이콘) | WeatherService |
| `partner_weather` | 파트너 지역 날씨 | WeatherService |
| `next_date_days` | 다음 데이트까지 D-N | schedules (is_date=true) |
| `next_date_label` | 다음 데이트 날짜 문자열 ("3월 28일") | schedules |

---

## 2. 기술 스택

| 영역 | 기술 |
|------|------|
| Flutter (데이터 전달) | `home_widget: ^0.9.0` (이미 설치됨) |
| Android 위젯 | AppWidgetProvider (Kotlin) + XML RemoteViews |
| iOS 위젯 | WidgetKit Extension (Swift) |
| 데이터 공유 | Android: SharedPreferences / iOS: App Groups |

---

## 3. 구현 범위

### Flutter (Dart) 작업
- [ ] `home_widget_service.dart` 전면 재작성 (주석 해제 + 데이터 확장)
- [ ] `home_screen.dart` 에서 데이터 로드 후 위젯 업데이트 호출
- [ ] `main.dart` 앱 시작 시 위젯 초기화

### Android 네이티브 작업
- [ ] `CoupleWidgetProvider.kt` — AppWidgetProvider 구현
- [ ] `res/layout/widget_small.xml` — Small 위젯 레이아웃
- [ ] `res/layout/widget_medium.xml` — Medium 위젯 레이아웃
- [ ] `res/xml/widget_info_small.xml` — 위젯 메타데이터 (크기 등)
- [ ] `res/xml/widget_info_medium.xml`
- [ ] `AndroidManifest.xml` — receiver 등록

### iOS 네이티브 작업
- [ ] Xcode에서 Widget Extension Target 추가 (`CoupleWidget`)
- [ ] `CoupleWidget.swift` — WidgetKit Small/Medium 뷰
- [ ] `Info.plist` App Group 설정 (`group.com.coupleapp`)
- [ ] `Runner/AppDelegate.swift` — App Group 초기화

---

## 4. 데이터 흐름

```
[Supabase] → [HomeService] → [HomeScreen]
                                  ↓
                        HomeWidgetService.updateWidget()
                                  ↓
              ┌───────────────────┴───────────────────┐
              ↓                                       ↓
   Android SharedPreferences              iOS App Groups UserDefaults
              ↓                                       ↓
   CoupleWidgetProvider (onUpdate)        WidgetKit Timeline Provider
              ↓                                       ↓
        RemoteViews XML                    SwiftUI Widget View
```

---

## 5. 위젯 UI 디자인

### Small 위젯 (2×2)
```
┌─────────────────┐
│  커플듀티   💑  │
│   D + 365       │
├─────────────────┤
│  나  │ 회의 10시│
│  파트│ 여유로운  │
└─────────────────┘
```

### Medium 위젯 (4×2)
```
┌───────────────────────────────────────┐
│  커플듀티  💑              D + 365    │
├───────────────────┬───────────────────┤
│  나    회의 10:00 │  🌤 내 지역  18°  │
│  파트  외출       │  🌧 파트너  12°   │
├───────────────────┴───────────────────┤
│  📅 다음 데이트  3월 28일  D-5        │
└───────────────────────────────────────┘
```

---

## 6. Android 패키지 정보

| 항목 | 값 |
|------|----|
| 패키지명 | `com.coupleduty.app` |
| Widget Provider 클래스 | `com.coupleduty.app.CoupleWidgetProvider` |
| SharedPreferences Key | `FlutterSharedPreferences` (home_widget 기본값) |

---

## 7. iOS 설정 정보

| 항목 | 값 |
|------|----|
| Bundle ID | `com.coupleduty.app` |
| Widget Extension Bundle ID | `com.coupleduty.app.CoupleWidget` |
| App Group ID | `group.com.coupleapp` |
| Widget Kind | `CoupleWidgetSmall`, `CoupleWidgetMedium` |

---

## 8. 구현 순서

1. **Flutter** `home_widget_service.dart` 재작성
2. **Android** Kotlin Provider + XML 레이아웃 작성
3. **Android** `AndroidManifest.xml` receiver 등록
4. **iOS** Widget Extension Swift 코드 작성
5. **iOS** Xcode 설정 안내 (App Group, Target 추가)
6. **Flutter** HomeScreen에서 위젯 업데이트 호출

---

## 9. 제외 범위 (이번 버전)

- 위젯 탭 시 특정 화면으로 딥링크 이동 (추후)
- 위젯 내 날씨 정보 (추후)
- 위젯 커스터마이징 UI (추후)
