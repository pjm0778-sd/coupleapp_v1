# OCR 스케줄 프롬프트 재설계 - 설계서

> **Feature**: ocr-schedule-prompt
> **Project**: coupleapp_v1
> **Date**: 2026-03-14
> **대상 파일**: `supabase/functions/ocr-schedule/index.ts`
> **참고**: `docs/01-plan/features/ocr-schedule-prompt.plan.md`

---

## 1. 프롬프트 전문 (실제 코드에 들어갈 문안)

### 1.1 useMapping=false — 자유 인식 모드

```
당신은 달력 이미지에서 일정을 추출하는 전문가입니다.

이미지는 안드로이드, 아이폰, 구글 캘린더, 삼성 캘린더 등 어떤 달력 앱의 캡처일 수도 있습니다.
이미지에 보이는 모든 일정을 빠짐없이 추출하세요.

추출 시 아래 사항을 반드시 지키세요:
- 여러 날에 걸쳐 가로 막대(bar) 형태로 표시된 일정은 시작일과 종료일을 정확히 파악해서 하나의 일정으로 추출
- 같은 날짜에 일정이 여러 개 있으면 전부 추출
- 이미지에서 연도와 월을 찾을 수 없으면 기본값 사용: ${targetYear}년 ${targetMonth}월
- 해당 월의 날짜 범위를 벗어나는 이전 달 또는 다음 달 일정은 제외
- 일정이 없는 날짜는 포함하지 않음

반드시 아래 JSON 형식으로만 응답하세요. 코드블록(```) 없이 순수 JSON만 출력하세요:
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [
    {
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "work_type": "일정명 또는 색상 기반 분류",
      "color_hex": "#RRGGBB",
      "start_time": "HH:mm",
      "end_time": "HH:mm"
    }
  ]
}

규칙:
- 하루짜리 일정은 start_date와 end_date를 동일하게 입력
- start_time, end_time은 이미지에 시간 정보가 있을 때만 포함, 없으면 해당 필드 생략
- color_hex는 일정의 배경색 또는 마커 색상 (#RRGGBB 형식)
```

---

### 1.2 useMapping=true — 매핑 참고 모드

```
당신은 달력 이미지에서 일정을 추출하는 전문가입니다.

이미지는 안드로이드, 아이폰, 구글 캘린더, 삼성 캘린더 등 어떤 달력 앱의 캡처일 수도 있습니다.
이미지에 보이는 모든 일정을 빠짐없이 추출하세요.

추출 시 아래 사항을 반드시 지키세요:
- 여러 날에 걸쳐 가로 막대(bar) 형태로 표시된 일정은 시작일과 종료일을 정확히 파악해서 하나의 일정으로 추출
- 같은 날짜에 일정이 여러 개 있으면 전부 추출
- 이미지에서 연도와 월을 찾을 수 없으면 기본값 사용: ${targetYear}년 ${targetMonth}월
- 해당 월의 날짜 범위를 벗어나는 이전 달 또는 다음 달 일정은 제외
- 일정이 없는 날짜는 포함하지 않음

아래는 사용자가 등록한 색상-근무형태 매핑입니다:
${colorMappingText}

각 일정의 색상이 위 매핑 중 하나와 유사하면 해당 work_type과 start_time, end_time을 사용하세요.
유사한 매핑이 없으면 이미지에서 읽은 텍스트나 색상 그대로 사용하세요.

반드시 아래 JSON 형식으로만 응답하세요. 코드블록(```) 없이 순수 JSON만 출력하세요:
{
  "year": 연도숫자,
  "month": 월숫자,
  "schedules": [
    {
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "work_type": "일정명",
      "color_hex": "#RRGGBB",
      "start_time": "HH:mm",
      "end_time": "HH:mm"
    }
  ]
}

규칙:
- 하루짜리 일정은 start_date와 end_date를 동일하게 입력
- start_time, end_time은 매핑에 시간 정보가 있거나 이미지에 표시된 경우에만 포함, 없으면 생략
- color_hex는 일정의 배경색 또는 마커 색상 (#RRGGBB 형식)
```

---

## 2. JSON 스키마

### 2.1 응답 구조

```typescript
interface OcrResponse {
  year: number
  month: number
  schedules: Schedule[]
}

interface Schedule {
  start_date: string      // "YYYY-MM-DD" — 필수
  end_date: string        // "YYYY-MM-DD" — 필수 (하루짜리는 start_date와 동일)
  work_type: string       // 일정명 — 필수
  color_hex: string       // "#RRGGBB" — 필수
  start_time?: string     // "HH:mm" — 선택
  end_time?: string       // "HH:mm" — 선택
}
```

### 2.2 예시

```json
{
  "year": 2026,
  "month": 3,
  "schedules": [
    {
      "start_date": "2026-03-03",
      "end_date": "2026-03-06",
      "work_type": "출장",
      "color_hex": "#4285F4"
    },
    {
      "start_date": "2026-03-10",
      "end_date": "2026-03-10",
      "work_type": "팀 회의",
      "color_hex": "#EA4335",
      "start_time": "14:00",
      "end_time": "15:00"
    },
    {
      "start_date": "2026-03-10",
      "end_date": "2026-03-10",
      "work_type": "점심 약속",
      "color_hex": "#34A853",
      "start_time": "12:00",
      "end_time": "13:00"
    }
  ]
}
```

---

## 3. index.ts 변경 상세

### 3.1 프롬프트 교체

```typescript
// useMapping=true
prompt = `당신은 달력 이미지에서 일정을 추출하는 전문가입니다.
...
`

// useMapping=false
prompt = `당신은 달력 이미지에서 일정을 추출하는 전문가입니다.
...
`
```

### 3.2 JSON 파싱 로직 보강

**현재 코드** (line 102~103):
```typescript
const match = content.match(/\{[\s\S]*\}/)
const resultJson = match ? JSON.parse(match[0]) : { year: targetYear, month: targetMonth, schedules: [] }
```

**변경 코드**:
```typescript
const cleaned = content
  .replace(/```json\s*/gi, '')
  .replace(/```\s*/g, '')
  .trim()

const match = cleaned.match(/\{[\s\S]*\}/)
const resultJson = match
  ? JSON.parse(match[0])
  : { year: targetYear, month: targetMonth, schedules: [] }
```

### 3.3 변경 범위 요약

| 위치 | 변경 내용 |
|------|----------|
| line 19~52 (prompt 변수) | 두 모드 프롬프트 전면 교체 |
| line 102~103 (파싱 로직) | 코드블록 제거 후 파싱으로 보강 |
| 나머지 | 변경 없음 |

---

## 4. colorMappingText 형식 (참고)

현재 코드의 colorMappingText 생성 방식은 유지합니다:

```typescript
const colorMappingText = (colorMappings as { color_hex: string; work_type: string; start_time?: string; end_time?: string }[])
  .map((m) => `${m.color_hex} → ${m.work_type} (${m.start_time || ''}~${m.end_time || ''})`)
  .join('\n')
```

예시 출력:
```
#FF0000 → 야간 (22:00~06:00)
#0000FF → 주간 (09:00~18:00)
#00FF00 → 휴무 (~)
```

---

## 5. 구현 체크리스트

- [ ] `useMapping=false` 프롬프트 교체
- [ ] `useMapping=true` 프롬프트 교체
- [ ] JSON 파싱 로직 보강 (코드블록 제거)
- [ ] 로컬에서 다양한 달력 이미지로 테스트
- [ ] Edge Function 배포
