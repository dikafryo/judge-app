# 온라인 심사 시스템 — 안드로이드 앱

**심사위원 화면은 네이티브**(Flutter)이고, **관리자 화면은 아직 웹**(WebView)이다.
서버는 `https://judge.sw4u.kr` 로 고정되어 있으며 `/api/v1` REST API 로만 통신한다.

플레이스토어에 올리지 않고 `https://judge.sw4u.kr/app` 에서 APK 를 직접 배포한다.
(`neisme-knight` 와 같은 방식·같은 도구 체인)

> **웹은 없어지지 않는다.** 아이폰 사용자와 데스크톱 관리자는 계속 웹을 쓴다.
> 따라서 심사 화면을 고칠 때는 **이 앱과 `/var/services/web/sw4u/judge` 의 Blade 화면 두 곳을
> 모두 고쳐야 한다.** 한쪽만 고치면 같은 행사를 두 사람이 다르게 보게 된다.

## 구조

```
lib/
  core/      config(서버 주소 고정) · api(Bearer 토큰 클라이언트) · brand(아이콘 마크)
  models/    payload — /api/v1/judge/me 응답 = 오프라인 동작의 전부
  store/     local_store(기기 저장) · judge_session(상태·전송 대기열) · queued_op
  judge/     entry · scan(QR) · candidates · scoring · signature
  admin/     admin_webview — 3단계에서 네이티브로 대체 예정
```

## 이 앱이 반드시 지켜야 하는 것

1. **화면은 언제나 로컬 상태를 그린다.** 저장을 누르면 기기를 먼저 고치고 대기열에 넣은 뒤
   전송한다. 서버가 멱등(같은 요청을 다시 보내도 결과가 같음)이라 재전송이 안전하다.
2. **대기열이 남아 있으면 서버 상태를 새로 받지 않는다.** 받아 버리면 아직 못 보낸 점수가
   서버의 옛 값으로 덮여 사라진다. (`JudgeSession.sync`)
3. **거절은 사유별로 다르게 다룬다** — 422·423 은 대기열에서 빼고(다시 보내도 같다),
   401 은 "코드 만료"로 번역해 재입장을 안내하고, 연결 실패만 남겨서 다시 보낸다.
4. **QR 은 주소 형식을 받아들여야 한다.** 이미 인쇄해 나눠 준 심사위원 카드의 QR 이
   `.../judge/483920` 형태이고, 그 카드는 다시 만들 수 없다.
5. **User-Agent 의 `JudgeApp/<버전>`** — 관리자 WebView 에서 서버가 이 표식을 보고
   "앱 설치" 안내를 감춘다.

## 개발

```bash
export PATH="/home/dikafryo/flutter/bin:$PATH"
export JAVA_HOME=/home/dikafryo/jdk

flutter pub get --offline   # 의존성은 pub 캐시에 있는 버전으로 고정되어 있다
flutter analyze
flutter test
flutter build apk --debug   # 릴리스 키 없이 컴파일만 확인
```

의존성 버전(`webview_flutter: 4.9.0` 등)이 **고정**되어 있는 이유는 pub 캐시에 이미 받아져 있어
네트워크 없이 빌드되기 때문이다. 올릴 때는 캐시에 해당 버전이 있는지 먼저 확인할 것.

### QR 인식 모델을 APK 에 넣지 않는다

`android/gradle.properties` 의 `dev.steenbakker.mobile_scanner.useUnbundled=true` 는
ML Kit 바코드 모델을 APK 에 넣지 않고 Google Play 서비스에서 받아 쓰게 한다.
**넣으면 APK 가 19MB → 34MB 로 커진다.** 대신 모델을 아직 안 받은 상태로 완전 오프라인이면
QR 스캔이 안 되는데, 그때도 접속 코드를 직접 입력해 입장할 수 있고
매니페스트의 `com.google.mlkit.vision.DEPENDENCIES` 로 설치 직후 미리 받아 두게 해 놓았다.

## Android 릴리스 서명

키는 저장소 밖에 둔다. **이 키를 잃어버리면 기존 설치본에 업데이트를 내보낼 수 없고,
사용자가 앱을 지우고 다시 깔아야 한다.**

```bash
mkdir -p ~/.config/judge-app && chmod 700 ~/.config/judge-app

keytool -genkeypair -v \
  -keystore ~/.config/judge-app/release-signing.jks \
  -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 -alias judge
```

이어서 `~/.config/judge-app/key.properties` 를 만든다 (mode 0600):

```properties
keyAlias=judge
keyPassword=<키 비밀번호>
storeFile=/home/dikafryo/.config/judge-app/release-signing.jks
storePassword=<키스토어 비밀번호>
```

마지막으로 인증서 지문을 기록해 둔다. 게시 스크립트가 매번 이 값과 대조해,
다른 키로 서명된 APK 가 배포되는 것을 막는다.

```bash
keytool -list -v -keystore ~/.config/judge-app/release-signing.jks -alias judge \
  | sed -nE 's/^.*SHA256: (.*)$/\1/p' | head -n 1 > android/release-signing.sha256
```

키스토어와 `key.properties` 는 `/var/services/target/private/judge-app/` 에도 백업한다.
다른 환경에서는 `JUDGE_APP_KEY_PROPERTIES` 로 경로를 지정한다.

> 키가 없는 상태에서 릴리스 빌드를 시도하면 Gradle 이 빌드를 중단한다.
> 디버그 키로 서명된 APK 가 실수로 배포되는 것을 막기 위한 장치다.

## 배포

```bash
./scripts/build_and_publish.sh              # 분석 → 테스트 → 빌드 → 서명대조 → 게시
./scripts/build_and_publish.sh --no-publish # 게시 없이 검증까지만
./scripts/build_and_publish.sh --skip-build # 이미 빌드된 APK 를 검증·게시
```

게시하면 `judge/public/downloads/` 에 APK 가, `judge/public/app-release.json` 에 메타데이터가 놓이고
`https://judge.sw4u.kr/app` 페이지가 즉시 새 버전을 가리킨다.

**새 버전을 낼 때는 `pubspec.yaml` 의 `version: X.Y.Z+build` 를 반드시 올린다.**
`build` 번호(= `versionCode`)가 올라가지 않으면 기기가 업데이트로 인식하지 않고,
앱 안의 업데이트 알림도 뜨지 않는다.

## 실기기 확인 항목

앱을 고친 뒤에는 이것들을 눈으로 확인한다. 서버에는 안드로이드 기기가 없어 자동화할 수 없다.

1. 접속 코드로 입장 — 잘못된 코드를 여섯 번 넣으면 429(잠시 후 다시)가 뜨는지
2. **QR 스캔 입장** — 인쇄된 심사위원 카드의 QR 로 바로 들어가지는지
3. 채점 — `+`/`−` 를 길게 누르면 빨라지는지, 숫자를 눌러 0.5점을 직접 넣을 수 있는지
4. `저장하고 다음 →` 으로 목록에 들르지 않고 다음 대상까지 이어지는지
5. **오프라인 핵심 시험** — 입장 → 비행기모드 → **앱 전체가 그대로 동작**하는지 →
   채점·서명 → `대기` 배지 → 비행기모드 해제 → 자동 전송 → **웹 관리자 대시보드에 반영**
6. 앱을 완전히 껐다 켜도 대기 중인 입력이 살아 있는지
7. 행사를 마감한 뒤 앱이 **"코드 만료"** 로 안내하는지 (404 를 그대로 노출하지 않는지)
8. 서명이 최종집계표에 웹에서 한 것과 같은 모양으로 실리는지
