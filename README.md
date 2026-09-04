# 온라인 심사 시스템 — 안드로이드 앱

`https://judge.sw4u.kr` 을 WebView 로 감싸는 얇은 껍데기 앱이다.
심사 화면 자체는 서버의 웹 화면이므로, **화면을 고치는 일은 이 프로젝트가 아니라
`/var/services/web/sw4u/judge` 에서 한다.** 여기서 고칠 것은 앱 껍데기의 동작뿐이다.

플레이스토어에 올리지 않고 `https://judge.sw4u.kr/app` 에서 APK 를 직접 배포한다.
(`neisme-knight` 와 같은 방식·같은 도구 체인)

## 이 앱이 반드시 지켜야 하는 것

1. **DOM storage** — 심사 화면의 오프라인 대기열이 `localStorage` 에 의존한다. 꺼지면 통째로 죽는다.
2. **User-Agent 의 `JudgeApp/<버전>`** — 서버가 이 표식을 보고 앱 안에서 "앱 설치"·인쇄 버튼을 감춘다.
3. **외부 링크는 브라우저로** — 심사 사이트 밖 주소는 앱에 가두지 않는다.

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

앱을 고친 뒤에는 이 다섯 가지를 눈으로 확인한다. 서버에는 안드로이드 기기가 없어 자동화할 수 없다.

1. 심사 화면이 뜨는지
2. 뒤로가기 — 웹 히스토리를 따라가다 최상단에서 종료 확인이 뜨는지
3. 헤더의 neis.me 로고가 **외부 브라우저**로 열리는지
4. **점수 입력 → 비행기모드 → 제출 → `대기` 배지 → 비행기모드 해제 → 자동 전송**
   (WebView 에서 `localStorage` 와 서비스워커가 실제로 사는지 확인하는 핵심 시험)
5. 앱 안에서 "앱 설치"·인쇄 버튼이 보이지 않는지
