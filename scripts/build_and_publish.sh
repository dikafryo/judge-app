#!/usr/bin/env bash
#
# 릴리스 APK 를 만들어 judge.sw4u.kr 에 게시한다.
# neisme-knight 의 같은 이름 스크립트를 옮겨온 것으로, 흐름과 안전장치가 같다.
#
#   analyze → test → release 빌드 → 서명 인증서 지문 대조 → 원자적 배치 → app-release.json
#
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/home/dikafryo/flutter/bin/flutter}"
JAVA_HOME="${JAVA_HOME:-/home/dikafryo/jdk}"
WEB_ROOT="${WEB_ROOT:-/var/services/web/sw4u/judge/public}"
APK_SOURCE="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
SIGNING_PROPERTIES="${JUDGE_APP_KEY_PROPERTIES:-${XDG_CONFIG_HOME:-$HOME/.config}/judge-app/key.properties}"
EXPECTED_CERT_FILE="$PROJECT_ROOT/android/release-signing.sha256"
APK_PREFIX="judge"
SKIP_BUILD=false
PUBLISH=true

usage() {
  echo "사용법: $0 [--skip-build] [--no-publish]"
  echo "  --skip-build  기존 app-release.apk 를 빌드 없이 검증·게시"
  echo "  --no-publish  검증과 빌드만 하고 웹 게시는 생략"
}

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    --no-publish) PUBLISH=false ;;
    -h|--help) usage; exit 0 ;;
    *) echo "알 수 없는 옵션: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -x "$FLUTTER_BIN" ]] || { echo "Flutter 실행 파일이 없습니다: $FLUTTER_BIN" >&2; exit 1; }
[[ -x "$JAVA_HOME/bin/javac" ]] || { echo "Java 컴파일러가 없습니다: $JAVA_HOME/bin/javac" >&2; exit 1; }

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

cd "$PROJECT_ROOT"

if [[ "$SKIP_BUILD" == false ]]; then
  if [[ ! -r "$SIGNING_PROPERTIES" ]]; then
    echo "릴리스 서명 설정을 읽을 수 없습니다: $SIGNING_PROPERTIES" >&2
    echo "README 의 'Android 릴리스 서명' 절을 먼저 따라 주세요." >&2
    exit 1
  fi
  export JUDGE_APP_KEY_PROPERTIES="$SIGNING_PROPERTIES"

  echo "[1/5] 정적 분석"
  "$FLUTTER_BIN" analyze
  echo "[2/5] 테스트"
  "$FLUTTER_BIN" test
  echo "[3/5] Android 릴리스 APK 빌드 (arm64 전용)"
  # arm64 만 넣어 용량을 1/3 로 줄인다. 전 아키텍처를 담으면 45MB, arm64 만이면 15MB 안팎.
  # 2019년 이전 32비트 전용 기기는 설치되지 않는다 — 그런 기기를 지원해야 하면
  # --target-platform 을 빼거나 android-arm 을 함께 지정할 것.
  "$FLUTTER_BIN" build apk --release --target-platform android-arm64
else
  echo "[1~3/5] 빌드 생략"
fi

[[ -f "$APK_SOURCE" ]] || { echo "APK 를 찾을 수 없습니다: $APK_SOURCE" >&2; exit 1; }

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$(sed -nE 's/^sdk\.dir=(.*)$/\1/p' android/local.properties | head -n 1)}"
APKSIGNER="${APKSIGNER:-$(find "$ANDROID_SDK_ROOT/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner 2>/dev/null | sort -V | tail -n 1)}"
[[ -x "$APKSIGNER" ]] || { echo "apksigner 를 찾을 수 없습니다. ANDROID_SDK_ROOT 를 확인하세요." >&2; exit 1; }
[[ -r "$EXPECTED_CERT_FILE" ]] || { echo "서명 지문 파일을 읽을 수 없습니다: $EXPECTED_CERT_FILE" >&2; exit 1; }

echo "[4/5] 서명 검증 및 인증서 지문 대조"
"$APKSIGNER" verify "$APK_SOURCE"
EXPECTED_CERT_SHA256="$(tr -d ':[:space:]' < "$EXPECTED_CERT_FILE" | tr '[:lower:]' '[:upper:]')"
ACTUAL_CERT_SHA256="$("$APKSIGNER" verify --print-certs "$APK_SOURCE" \
  | sed -nE 's/^Signer #1 certificate SHA-256 digest: (.*)$/\1/p' \
  | head -n 1 | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
if [[ -z "$ACTUAL_CERT_SHA256" || "$ACTUAL_CERT_SHA256" != "$EXPECTED_CERT_SHA256" ]]; then
  echo "APK 서명 인증서가 등록된 정식 키와 다릅니다. 게시를 중단합니다." >&2
  exit 1
fi

VERSION_SPEC="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml | head -n 1)"
if [[ ! "$VERSION_SPEC" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  echo "pubspec.yaml 의 version 형식이 올바르지 않습니다: $VERSION_SPEC" >&2
  exit 1
fi

VERSION_NAME="${BASH_REMATCH[1]}"
BUILD_NUMBER="${BASH_REMATCH[2]}"
PUBLISHED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
SHA256="$(sha256sum "$APK_SOURCE" | awk '{print $1}')"
SIZE_BYTES="$(stat -c '%s' "$APK_SOURCE")"
VERSIONED_APK="${APK_PREFIX}-${VERSION_NAME}-${BUILD_NUMBER}.apk"
LATEST_APK="${APK_PREFIX}-latest.apk"

if [[ "$PUBLISH" == false ]]; then
  echo "[5/5] 게시 생략"
  echo
  echo "검증 완료: v${VERSION_NAME} (${BUILD_NUMBER})  ${SIZE_BYTES} bytes"
  echo "SHA-256: $SHA256"
  exit 0
fi

echo "[5/5] v${VERSION_NAME} (${BUILD_NUMBER}) 게시"
install -d -m 2755 "$WEB_ROOT/downloads"

# 내려받는 중인 조각난 APK 가 노출되지 않도록 임시 이름으로 복사한 뒤 교체한다.
for name in "$VERSIONED_APK" "$LATEST_APK"; do
  cp "$APK_SOURCE" "$WEB_ROOT/downloads/.${name}.tmp"
  mv "$WEB_ROOT/downloads/.${name}.tmp" "$WEB_ROOT/downloads/$name"
done

RELEASE_TMP="$WEB_ROOT/.app-release.json.tmp"
printf '{\n  "version": "%s",\n  "build": %s,\n  "apk": "downloads/%s",\n  "sizeBytes": %s,\n  "sha256": "%s",\n  "publishedAt": "%s"\n}\n' \
  "$VERSION_NAME" "$BUILD_NUMBER" "$VERSIONED_APK" "$SIZE_BYTES" "$SHA256" "$PUBLISHED_AT" \
  > "$RELEASE_TMP"
mv "$RELEASE_TMP" "$WEB_ROOT/app-release.json"

# judge 저장소 권한 규약: PHP-FPM 이 www-data 로 읽는다
chgrp -R www-data "$WEB_ROOT/downloads" "$WEB_ROOT/app-release.json" 2>/dev/null || true
chmod 644 "$WEB_ROOT/downloads/"*.apk "$WEB_ROOT/app-release.json"

echo
echo "게시 완료: https://judge.sw4u.kr/app"
echo "APK: $WEB_ROOT/downloads/$VERSIONED_APK"
echo "SHA-256: $SHA256"
