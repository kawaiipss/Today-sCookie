# Changelog

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
