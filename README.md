# 오늘의 쿠키 (Today's Cookie)

포츈쿠키를 탭하면 Claude AI가 생성한 오늘의 운세를 확인할 수 있는 Flutter 앱.

---

## 아키텍처

```
Flutter 앱
  └─ Firebase Anonymous Auth     ← 유저 식별 (익명)
  └─ Firebase Functions          ← Claude API 프록시 (API 키 서버 보관)
       └─ Claude Sonnet (claude-sonnet-4-6)
       └─ Firestore              ← 하루 1회 제한 캐시
  └─ Google AdMob                ← 전면 광고 + 배너 광고
```

---

## 개발 환경 설정

### 필수 도구

```bash
# Flutter SDK (^3.11.1)
flutter --version

# Firebase CLI
npm install -g firebase-tools
firebase login

# FlutterFire CLI
dart pub global activate flutterfire_cli
```

### 1. 패키지 설치

```bash
# Flutter 패키지
flutter pub get

# Functions 패키지
cd functions && npm install && cd ..
```

### 2. Firebase 프로젝트 연결

Firebase Console에서 프로젝트를 생성한 후:

```bash
# FlutterFire 초기화 — lib/firebase_options.dart 자동 생성
flutterfire configure
```

생성된 `lib/firebase_options.dart`는 `.gitignore`에 포함되어 있으므로
각 개발자가 로컬에서 별도로 실행해야 합니다.

### 3. `.firebaserc` 프로젝트 ID 설정

```json
{
  "projects": {
    "default": "실제-firebase-프로젝트-id"
  }
}
```

---

## Firebase Functions 환경변수 설정

Claude API 키는 코드에 하드코딩하지 않고 **Google Secret Manager**로 관리합니다.

### 프로덕션 배포용 (Secret Manager)

```bash
# 1. Claude API 키를 Secret Manager에 등록
firebase functions:secrets:set CLAUDE_API_KEY
# 프롬프트에 sk-ant-... 값 입력

# 2. 등록된 시크릿 확인
firebase functions:secrets:access CLAUDE_API_KEY

# 3. Functions 배포 (시크릿이 자동으로 함수에 마운트됨)
firebase deploy --only functions
```

### 로컬 에뮬레이터용

```bash
# functions/.env 파일 생성 (gitignore 적용됨)
echo "CLAUDE_API_KEY=sk-ant-여기에키입력" > functions/.env

# 에뮬레이터 실행
firebase emulators:start --only functions
```

> `functions/.env`는 `.gitignore`에 등록되어 있어 절대 커밋되지 않습니다.

---

## Firebase Console 설정

배포 전 Firebase Console에서 아래 항목을 활성화해야 합니다.

| 항목 | 경로 | 설정값 |
|---|---|---|
| 익명 인증 | Authentication → 로그인 방법 | 익명 **활성화** |
| Firestore | Firestore Database | 프로덕션 모드로 생성 |
| Firestore 규칙 | Firestore → 규칙 탭 | `firestore.rules` 파일 배포 |

---

## 배포

### Firestore 규칙 + Functions 배포

```bash
firebase deploy --only functions,firestore:rules
```

### Flutter 앱 빌드 (API 키 불필요 — Functions으로 이전됨)

```bash
# Android App Bundle
flutter build appbundle --obfuscate --split-debug-info=build/debug-info

# 결과물
# build/app/outputs/bundle/release/app-release.aab
```

---

## 보안 체크리스트

| 항목 | 상태 |
|---|---|
| Claude API 키 코드 하드코딩 | 없음 — Secret Manager 전용 |
| `google-services.json` gitignore | ✅ |
| `lib/firebase_options.dart` gitignore | ✅ |
| `functions/node_modules/` gitignore | ✅ |
| `functions/.env` gitignore | ✅ |
| `android/key.properties` gitignore | ✅ |
| Firestore 클라이언트 직접 접근 | 차단 (`allow read, write: if false`) |

---

## 프로젝트 구조

```
lib/
├── main.dart              # 진입점, Firebase + AdMob 초기화
├── home_screen.dart       # 메인 UI, 광고·운세 흐름 관리
├── fortune_service.dart   # Firebase Functions 호출, 캐시 관리
├── ad_service.dart        # AdMob 전면 광고 (Completer 기반)
└── app_strings.dart       # 한/영 이중 언어 문자열

functions/
├── index.js               # getDailyFortune Cloud Function
└── package.json

firestore.rules            # Firestore 보안 규칙
firebase.json              # Firebase 프로젝트 설정
.firebaserc                # 프로젝트 ID 바인딩
```

---

## 광고 단위 ID

| 항목 | ID |
|---|---|
| AdMob 앱 ID | `ca-app-pub-3117796092766601~6850954938` |
| 전면 광고 | `ca-app-pub-3117796092766601/4014017769` |
| 배너 광고 | `ca-app-pub-3117796092766601/8164485532` |
