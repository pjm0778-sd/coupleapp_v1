# Plan: home-redesign

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | home-redesign |
| 시작일 | 2026-03-21 |

### Value Delivered

| 관점 | 내용 |
|------|------|
| Problem | 현재 홈화면은 정보 밀도는 있으나 감성 몰입감이 부족하고, 카드 배치가 정적이며 커플 앱다운 설렘이 없음 |
| Solution | 7개 로테이션 헤더 문구 + Cormorant 폰트 + 4장 스와이프 카드 구조로 매 방문마다 새로운 감성 경험 제공 |
| Function UX Effect | 스와이프로 정보 탐색, 게이지로 다음 만남 기대감 시각화, 일정 토글로 오늘/내일 빠른 전환 |
| Core Value | "매일 켤 때마다 설레는 홈화면" — 커플 앱의 핵심 감성을 UI에서 직접 구현 |

---

## 1. 개요

### 1.1 배경
레퍼런스 디자인(파스텔 카드 + 대형 타이포 + 스와이프 카드)을 바탕으로 커플듀티 홈화면을 전면 리디자인. 기존 정적 벤토 그리드를 감성적인 스와이프 카드 구조로 전환.

### 1.2 목표
- 매 방문마다 달라지는 헤더 문구로 감성 몰입감 강화
- 4장 스와이프 카드로 핵심 정보(일정, 다음 만남, 교통, 중간지점) 접근성 향상
- Cormorant Garamond 폰트 도입으로 세련된 타이포그래피 구현

---

## 2. 기능 명세

### 2.1 헤더 - 7개 로테이션 문구

매 홈 방문 시 순서대로 순환 (SharedPreferences에 마지막 인덱스 저장):

| 순번 | 문구 | 포맷 |
|------|------|------|
| 0 | `{N} Days of Love` | 숫자 대형 + 텍스트 소형 |
| 1 | `Day {N} with You` | 동일 |
| 2 | `Together for {N} Days` | 동일 |
| 3 | `Our {N}th Page` | 동일 |
| 4 | `{N} Days of Us` | 동일 |
| 5 | `A Journey of {N} Days` | 동일 |
| 6 | `{N} & Still Counting` | 동일 |

**폰트**: Cormorant Garamond
- 숫자(`{N}`): Bold, 72px, textPrimary
- 나머지 텍스트: Light/Regular, 20px, textSecondary
- 위에 소형 서브텍스트: "안녕, [닉네임]" (14px, Noto Sans KR)

### 2.2 스와이프 카드 (PageView, 4장)

카드 높이: 화면 높이의 약 40% (약 300px)
카드 간격: 좌우 24px 패딩, 카드 사이 12px gap
페이지 인디케이터: 카드 하단 dot (4개)

---

#### Card 1 - 오늘 & 내일 일정

**레이아웃:**
```
┌─────────────────────────────────┐
│  [오늘]  [내일]   ← 상단 토글    │
│─────────────────────────────────│
│  나             파트너           │
│  ◉ 출근 08:00   ◉ 휴무          │
│  ◉ 저녁 약속    ─               │
│                                 │
│  (둘 다 휴무면) 💕 같이 쉬는 날!  │
└─────────────────────────────────┘
```

- 토글: 오늘/내일 전환, 기본값 오늘
- 나/파트너 2컬럼 레이아웃
- 둘 다 휴무인 경우 하이라이트 표시
- 일정 없으면 "일정 없음" 표시

**카드 컬러**: 화이트 배경, 상단 토글 액센트 컬러

---

#### Card 2 - 다음 만남

**레이아웃:**
```
┌─────────────────────────────────┐
│  다음 만남                       │
│                                 │
│    3월 28일 토요일               │  ← 날짜
│                                 │
│  ████████████████░░  D-3        │  ← 게이지
│                                 │
│  [N일째 보고 싶은 중이에요]       │  ← DB 있을 때
│  또는 [곧 만나요! 설레는 중 💕]   │  ← D-0 당일
└─────────────────────────────────┘
```

**게이지 로직:**
- `last_meeting` DB 있음: `progress = (today - last_meeting) / (next_meeting - last_meeting)`
- `last_meeting` DB 없음: `progress = (14 - days_until) / 14` (D-14 기준)
- D-0 당일: 게이지 100% + 색상 accent + 특별 문구

**하단 문구 (last_meeting DB 있을 때):**
- D > 1: `"N일째 보고 싶은 중이에요"` (N = today - last_meeting)
- D-0: `"오늘 드디어 만나는 날이에요 💕"`
- 다음 만남 없음: `"다음 데이트를 캘린더에 등록해봐요"`

**카드 컬러**: 파스텔 피치/로즈 계열

---

#### Card 3 - 교통편

**헤더 카피**: "가는 길도 설레어"
**서브 카피**: "지금 출발하면 언제 도착할까요"

**레이아웃:**
```
┌─────────────────────────────────┐
│  🚇 가는 길도 설레어              │
│  지금 출발하면 언제 도착할까요     │
│                                 │
│  [내 역] ──────→ [파트너 역]     │
│                                 │
│  (교통 정보 미리보기 또는 버튼)   │
│                    [바로가기 →]  │
└─────────────────────────────────┘
```

**카드 컬러**: 파스텔 민트/블루 계열

---

#### Card 4 - 중간지점

**헤더 카피**: "반반 거리, 완벽한 약속장소"
**서브 카피**: "서로의 중간, 딱 공평한 만남의 중심점"

**레이아웃:**
```
┌─────────────────────────────────┐
│  📍 반반 거리, 완벽한 약속장소    │
│  서로의 중간, 딱 공평한 만남의    │
│  중심점을 찾아드려요              │
│                                 │
│  [내 위치] ──●── [파트너 위치]   │
│                                 │
│                    [찾아보기 →]  │
└─────────────────────────────────┘
```

**카드 컬러**: 파스텔 라벤더/퍼플 계열

---

### 2.3 폰트 변경

| 용도 | 변경 전 | 변경 후 |
|------|--------|--------|
| 헤더 D+day 숫자 | Playfair Display | Cormorant Garamond Bold |
| 헤더 문구 텍스트 | Playfair Display | Cormorant Garamond Light |
| 나머지 본문 | Noto Sans KR | Noto Sans KR (유지) |

`pubspec.yaml`에 `cormorant_garamond` Google Fonts 추가 필요.

---

## 3. 데이터 요구사항

### 3.1 신규 필요 데이터
- `last_meeting_date`: 마지막 만남 날짜 (couples 테이블 또는 schedules에서 추출)

### 3.2 last_meeting 추출 방식
옵션 A: schedules 테이블에서 category='데이트' 이면서 date < today 인 가장 최근 항목 자동 추출
옵션 B: couples 테이블에 `last_met_at` 컬럼 추가 (수동 또는 자동 업데이트)

→ **옵션 A 권장** (별도 컬럼 불필요, 기존 데이터 활용)

**카테고리 조건**: `category IN ('데이트', '여행')` AND `date < today` 중 가장 최근 항목

### 3.3 SharedPreferences 키
- `home_phrase_index`: int, 마지막 표시된 문구 인덱스 (0~6)

---

## 4. 영향 범위

### 수정 파일
- `lib/features/home/screens/home_screen.dart` - 전면 재작성
- `lib/core/theme.dart` - 파스텔 카드 컬러 추가
- `lib/features/home/services/home_service.dart` - last_meeting 조회 추가
- `pubspec.yaml` - Cormorant Garamond 폰트 추가

### 삭제/대체
- `lib/features/home/widgets/dday_widget.dart` - 미사용 (bento 제거로)
- `lib/features/home/widgets/today_schedule_widget.dart` - Card 1으로 통합
- `lib/features/home/widgets/next_date_widget.dart` - Card 2으로 통합
- `lib/features/home/widgets/transport_preview_card.dart` - Card 3으로 통합

---

## 5. 구현 순서

1. `pubspec.yaml` Cormorant Garamond 추가
2. `AppTheme`에 파스텔 카드 컬러 4종 추가
3. 헤더 로테이션 위젯 (`_RotatingHeader`) 구현
4. `HomeService.getLastMeeting()` 추가
5. Card 1 (일정 토글) 구현
6. Card 2 (다음 만남 + 게이지) 구현
7. Card 3, 4 (교통/중간지점 카드) 구현
8. PageView + 인디케이터 조립
9. `home_screen.dart` 전체 교체
