# Plan: odsay-proxy (교통편 검색 — ODsay 프록시 + Flutter 클라이언트)

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | Flutter Web에서 `api.odsay.com`을 직접 호출하면 브라우저 CORS 정책에 의해 차단되어 교통편 검색 기능이 동작하지 않는다 |
| **Solution** | Supabase Edge Function을 ODsay API 프록시로 배포해 CORS를 우회하고, API 키를 서버 측 환경변수로 관리한다 |
| **Function UX Effect** | 커플이 앱에서 출발역/터미널과 도착역을 선택하면 KTX·SRT·무궁화·고속버스·시외버스 시간표를 통합 조회할 수 있다 |
| **Core Value** | 장거리 연애 커플이 만남 계획 수립 시 교통편을 앱 안에서 바로 확인할 수 있어 외부 검색 불필요 |

---

## 1. 배경 및 목적

### 1.1 문제 정의
- Flutter Web 앱(`coupleapp-v1.pages.dev`)에서 `https://api.odsay.com`을 fetch하면 CORS 에러 발생
- API 키를 클라이언트 코드에 넣으면 키 노출 위험

### 1.2 목표
- ODsay API CORS 프록시를 Supabase Edge Function으로 구축
- Flutter 교통 검색 기능(열차 3종 + 고속버스 + 시외버스) 완전 구현

---

## 2. 기능 요구사항

### 2.1 Supabase Edge Function (odsay-proxy)
- [ ] FR-01: ODsay API 5개 엔드포인트 프록시 지원
  - `trainTerminals`, `expressBusTerminals`, `intercityBusTerminals`
  - `trainServiceTime`, `searchInterBusSchedule`
- [ ] FR-02: API 키를 서버 환경변수(`ODSAY_API_KEY`)로 관리, 클라이언트 노출 없음
- [ ] FR-03: 허용 엔드포인트 화이트리스트(보안)
- [ ] FR-04: CORS 헤더 처리 (`Access-Control-Allow-Origin: *`)
- [ ] FR-05: JWT 인증 불필요 (`--no-verify-jwt` 배포)

### 2.2 Flutter TransportService
- [ ] FR-06: 역/터미널명 → ODsay stationID 조회 (캐시 포함)
- [ ] FR-07: 열차 시간표 조회 (`trainServiceTime`)
- [ ] FR-08: 고속버스 시간표 조회 (`searchInterBusSchedule`, class=4)
- [ ] FR-09: 시외버스 시간표 조회 (`searchInterBusSchedule`, class=6)
- [ ] FR-10: SRT Supabase DB 폴백 (ODsay SRT 미지원 시)
- [ ] FR-11: ODsay 시간 형식 정규화 (`"0500"` → `"05:00"`)
- [ ] FR-12: 운행 요일 필터링 (`runDay` 필드 기반)
- [ ] FR-13: 요금 파싱 (문자열/숫자/Map 형식 모두 지원)

### 2.3 Flutter UI
- [ ] FR-14: 출발/도착역 입력 + 날짜 선택
- [ ] FR-15: 열차/버스 결과 분리 탭 표시
- [ ] FR-16: SRT 전용 역 배너 표시

---

## 3. 비기능 요구사항
- API 응답 시간: 15초 이내
- 에러 시 graceful degradation (열차 실패해도 버스 표시)
- 역명 검색 결과 캐싱 (동일 역 중복 API 호출 방지)
