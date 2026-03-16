# 엑셀 근무표 직접 업로드 — Plan

> **Feature**: excel-schedule-import
> **Project**: coupleapp_v1
> **Version**: 유료 기능 (Premium)
> **Date**: 2026-03-17

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 병원·편의점·공장 등 엑셀 근무표를 쓰는 커플이 매달 수동으로 일정을 입력해야 하며, 사진 OCR은 복잡한 표 구조에서 오인식 위험이 있음 |
| **Solution** | .xlsx 파일을 직접 업로드하면 서버에서 파싱 후 이름 지정으로 해당 사람 근무 행을 추출해 달력에 자동 등록 (정확도 100%) |
| **Function/UX Effect** | 파일 선택 → 이름 입력 → 확인 → 저장 3단계로 한 달치 근무표를 30초 안에 등록 완료 |
| **Core Value** | 근무표가 있는 커플의 "매달 수동 입력" 고통 제거 — 유료 전환의 핵심 가치 제안 |

---

## 1. Overview

### 1.1 목적

엑셀(.xlsx) 근무표 파일을 직접 업로드하여 특정 이름의 근무 일정을 파싱하고 CoupleDuty 달력에 자동 등록한다. OCR 없이 파일을 직접 파싱하므로 정확도 100%를 보장한다.

### 1.2 타겟 사용자

- 병원 (간호사·의사 교대근무표)
- 편의점·마트 (주간/야간/휴무 근무표)
- 공장·물류 (교대 근무 스케줄)
- 기타 엑셀로 근무표를 관리하는 모든 직장

### 1.3 Scope

#### In Scope
- [ ] Flutter: .xlsx 파일 선택 (file_picker)
- [ ] Flutter: 이름 입력 UI
- [ ] Supabase Edge Function: Excel 파싱 (`excel-schedule-parse`)
- [ ] Edge Function: 이름 행 자동 탐색 + 날짜·근무 추출
- [ ] Flutter: 기존 OcrReviewScreen 재사용 (검토 → 저장)
- [ ] 커플 동시 추출 (나 + 파트너 이름 동시 지정)

#### Out of Scope
- [ ] .xls (구버전) 지원 — 추후 검토
- [ ] Google Sheets 연동 — 별도 기능
- [ ] 사진 OCR 방식 — 기존 기능 유지

---

## 2. 사용자 플로우

```
자동등록 화면
    ↓
"엑셀 파일 업로드" 카드 선택 (유료 배지)
    ↓
파일 선택 (.xlsx)
    ↓
이름 입력 화면
  - 내 이름: [홍길동      ]
  - 파트너 이름: [김영희   ] (선택 사항)
  - 대상 월: [2026년 3월 ▼]
    ↓
파싱 중... (Edge Function 호출)
    ↓
OcrReviewScreen (기존 재사용)
  - 내 일정 N건 / 파트너 일정 N건 표시
  - 수정·삭제 가능
    ↓
저장 → 달력 반영
```

---

## 3. Edge Function 설계 (`excel-schedule-parse`)

### 3.1 요청 형식

```typescript
{
  fileBase64: string,        // .xlsx 파일 base64
  myName: string,            // 내 이름 (필수)
  partnerName?: string,      // 파트너 이름 (선택)
  targetYear: number,
  targetMonth: number,
}
```

### 3.2 응답 형식

```typescript
{
  year: number,
  month: number,
  mySchedules: Schedule[],
  partnerSchedules: Schedule[],   // partnerName 없으면 빈 배열
}

interface Schedule {
  start_date: string,   // "YYYY-MM-DD"
  end_date: string,     // "YYYY-MM-DD" (하루짜리는 동일)
  work_type: string,    // 근무 종류 (주간/야간/휴무 등)
  color_hex: string,    // 근무 종류별 기본 색상
}
```

### 3.3 파싱 로직

```
1. base64 → Buffer → xlsx 파싱
2. 첫 번째 시트 선택
3. 이름 열 탐색: 각 행의 셀을 스캔하여 myName/partnerName 포함 행 인덱스 찾기
4. 날짜 행 탐색: 숫자(1~31) 또는 날짜 형식이 있는 행/열 헤더 찾기
5. 해당 이름 행의 날짜별 셀 값 추출
6. 근무 종류 정규화 (주간/야간/휴무/공휴일 등)
7. 근무 종류별 color_hex 매핑
```

### 3.4 근무 종류 색상 기본 매핑

| 근무 종류 키워드 | color_hex |
|----------------|-----------|
| 주간, D, Day | `#4CAF50` |
| 야간, N, Night | `#3F51B5` |
| 저녁, E, Evening | `#FF9800` |
| 휴무, 오프, Off, O | `#9E9E9E` |
| 공휴일, 휴가 | `#E91E63` |
| 기타 | `#607D8B` |

---

## 4. Flutter 구현

### 4.1 신규 파일

- `lib/features/schedule/screens/excel_import_screen.dart`
  - 파일 선택 버튼
  - 이름 입력 필드 (나 / 파트너)
  - 대상 월 선택
  - 업로드 → OcrReviewScreen으로 이동

### 4.2 기존 파일 수정

- `lib/features/schedule/screens/auto_registration_screen.dart`
  - "엑셀 파일 업로드" 카드 추가 (유료 배지)
- `lib/features/schedule/screens/ocr_review_screen.dart`
  - 커플 동시 추출 시 나/파트너 두 그룹으로 나눠 표시하는 모드 추가

### 4.3 패키지 추가

```yaml
# pubspec.yaml
file_picker: ^8.0.0    # 파일 선택
```

---

## 5. Edge Function 구현

### 5.1 파일명

`supabase/functions/excel-schedule-parse/index.ts`

### 5.2 파싱 라이브러리

Deno 환경에서 xlsx 파싱:
```typescript
import * as XLSX from "npm:xlsx@0.18.5"
```

---

## 6. 유료 기능 처리

### 6.1 현재 단계 (MVP)

- 별도 결제 시스템 없이 **기능 자체만 구현**
- UI에 "Premium" 배지 표시
- 실제 유료 게이트는 추후 in-app purchase 연동 시 추가

### 6.2 추후 유료 게이트 위치

- `ExcelImportScreen` 진입 시 구독 여부 확인
- 비구독자 → 결제 유도 다이얼로그

---

## 7. 구현 순서

1. [ ] Edge Function `excel-schedule-parse` 작성 및 로컬 테스트
2. [ ] `ExcelImportScreen` 구현 (파일 선택 + 이름 입력)
3. [ ] `AutoRegistrationScreen`에 엑셀 카드 추가
4. [ ] `OcrReviewScreen` 커플 동시 모드 지원
5. [ ] Edge Function 배포
6. [ ] 다양한 근무표 포맷으로 테스트

---

## 8. 성공 기준

| 기준 | 목표 |
|------|------|
| 파싱 정확도 | 100% (OCR 아닌 직접 파싱) |
| 이름 탐색 성공률 | 95% 이상 (다양한 표 구조 대응) |
| 처리 시간 | 3초 이내 |
| 지원 포맷 | .xlsx (Excel 2007 이상) |

---

## 9. 리스크

| Risk | Mitigation |
|------|------------|
| 엑셀 표 구조가 회사마다 다름 | 이름 탐색 로직을 유연하게 (열/행 방향 모두 탐색) |
| 날짜 헤더 형식이 다양함 | 숫자(1~31), 날짜 형식, 텍스트("1일") 모두 대응 |
| 대용량 파일 | 파일 크기 제한 5MB, 첫 번째 시트만 처리 |
| Deno에서 xlsx 라이브러리 호환성 | npm:xlsx 사용, 미지원 시 js-xlsx 대체 |
