# Changelog

## 1.0.3+8 (2026-07-05)

### 버그 수정
- 운세 문구 한글 깨짐 수정 — Claude API 응답을 청크 단위로 문자열 조립하며 멀티바이트 문자가 손상되던 버그 (`functions/index.js`)
- `Content-Type` 응답 헤더에 `charset=utf-8` 명시 — 클라이언트가 latin1로 잘못 디코딩하던 문제 수정
- 클라이언트에서도 `response.bodyBytes`를 UTF-8로 명시적 디코딩하도록 방어 코드 추가 (`lib/fortune_service.dart`)

### 변경 사항
- 운세 프롬프트의 테마·키워드를 서버가 랜덤으로 뽑아 명시하도록 변경 — 특정 테마("재물"+"흐름")로 쏠리던 현상 개선
- 버전 코드 7 → 8

---

## 1.0.0+4 (2026-06-25)

### 버그 수정
- `lib/firebase_options.dart` 누락 파일 추가 — Firebase 초기화 빌드 오류 수정
- Firebase 익명 인증(`signInAnonymously`) 무한 대기 버그 수정 — 10초 타임아웃 추가
- 운세 API 호출 실패 시 에러 로그 출력 추가 (디버깅용)

### 변경 사항
- 버전 코드 3 → 4

---

## 1.0.0+3 이전

- 초기 Flutter 프로젝트 세팅
- Firebase Auth, Cloud Functions, AdMob 연동
- Claude API 기반 일일 운세 생성 기능
- 포춘 쿠키 애니메이션 UI
