#!/usr/bin/env bash
#
# 플레이스토어 비공개 테스트 업로드.
#
# 전제 — 이 스크립트가 못 하는 일이 하나 있다.
#   Play Developer API 에는 **앱을 새로 만드는 메서드가 없다** (androidpublisher v3 의
#   applications 리소스에는 dataSafety 하나뿐). 앱 껍데기는 Play Console 웹에서 사람이
#   먼저 만들어야 하고, 이 스크립트는 그 다음부터를 자동화한다.
#
# 준비물
#   1) Play Console 에 kr.sw4u.judge_app 앱이 생성돼 있을 것
#   2) 그 앱에 서비스 계정이 초대돼 '버전 관리' 권한을 받았을 것
#   3) 서명된 AAB (flutter build appbundle --release)
#
# 사용법
#   play_upload.sh <app-release.aab> [트랙]
#     트랙 기본값 internal (비공개 내부 테스트). 비공개 알파 트랙은 alpha 를 준다.
#
#   SERVICE_ACCOUNT_JSON 으로 키 위치를, PLAY_PACKAGE 로 패키지명을 바꿀 수 있다.
#
set -euo pipefail

# --tracks 는 어떤 트랙이 열려 있는지만 확인하고 끝낸다 (아무것도 바꾸지 않는다).
LIST_ONLY=false
if [[ "${1:-}" == "--tracks" ]]; then LIST_ONLY=true; shift; fi

AAB="${1:-}"
TRACK="${2:-internal}"
if [[ "$LIST_ONLY" == false && -z "$AAB" ]]; then
  echo "사용법: play_upload.sh <app-release.aab> [트랙]  |  play_upload.sh --tracks" >&2
  exit 1
fi
PACKAGE="${PLAY_PACKAGE:-kr.sw4u.judge_app}"
SA="${SERVICE_ACCOUNT_JSON:-$HOME/Desktop/developer/google-service-account.json}"

API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE"

[[ "$LIST_ONLY" == true || -f "$AAB" ]] || { echo "AAB 를 찾을 수 없습니다: $AAB" >&2; exit 1; }
[[ -f "$SA" ]] || { echo "서비스 계정 키를 찾을 수 없습니다: $SA" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq 가 필요합니다." >&2; exit 1; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# ── 액세스 토큰 (서비스 계정 JWT → OAuth2) ───────────────────────────────────
issue_token() {
  local email now header claim sig
  email=$(jq -r .client_email "$SA")
  now=$(date +%s)
  header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
  claim=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","exp":%s,"iat":%s}' \
    "$email" "$((now + 3600))" "$now" | b64url)
  sig=$(printf '%s.%s' "$header" "$claim" \
    | openssl dgst -sha256 -sign <(jq -r .private_key "$SA") | b64url)

  curl -sS -X POST https://oauth2.googleapis.com/token \
    -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
    --data-urlencode "assertion=${header}.${claim}.${sig}" \
    | jq -r '.access_token // empty'
}

TOKEN=$(issue_token)
[[ -n "$TOKEN" ]] || { echo "액세스 토큰을 받지 못했습니다. 키가 유효한지 확인하세요." >&2; exit 1; }
AUTH=(-H "Authorization: Bearer $TOKEN")

# 실패하면 열어 둔 편집 세션을 반드시 버린다 — 남겨 두면 다음 업로드가 충돌한다.
EDIT=""
cleanup() {
  [[ -n "$EDIT" ]] && curl -sS -o /dev/null -X DELETE "$API/edits/$EDIT" "${AUTH[@]}" || true
}

# ── 편집 세션 ────────────────────────────────────────────────────────────────
echo "▸ 편집 세션 여는 중 ($PACKAGE)"
RESP=$(curl -sS -X POST "$API/edits" "${AUTH[@]}" -H 'Content-Length: 0')
EDIT=$(jq -r '.id // empty' <<<"$RESP")

if [[ -z "$EDIT" ]]; then
  echo "편집 세션을 열지 못했습니다:" >&2
  jq -r '.error.message // .' <<<"$RESP" >&2
  echo >&2
  echo "404 라면 Play Console 에 앱이 아직 없는 것이고," >&2
  echo "403 이라면 서비스 계정에 권한이 없는 것입니다." >&2
  exit 1
fi
trap cleanup EXIT

if [[ "$LIST_ONLY" == true ]]; then
  echo "▸ 트랙 목록"
  curl -sS "$API/edits/$EDIT/tracks" "${AUTH[@]}" \
    | jq -r '.tracks[]? | "  \(.track)\t버전 \((.releases[]?.versionCodes // ["-"]) | join(","))\t\(.releases[]?.status // "-")"'
  exit 0   # trap 이 편집 세션을 정리한다
fi

# ── AAB 업로드 ───────────────────────────────────────────────────────────────
echo "▸ AAB 업로드 중 ($(du -h "$AAB" | cut -f1))"
RESP=$(curl -sS -X POST \
  "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE/edits/$EDIT/bundles?uploadType=media" \
  "${AUTH[@]}" -H 'Content-Type: application/octet-stream' --data-binary "@$AAB")

VERSION_CODE=$(jq -r '.versionCode // empty' <<<"$RESP")
[[ -n "$VERSION_CODE" ]] || { echo "업로드 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }
echo "  versionCode $VERSION_CODE"

# ── 트랙 배정 ────────────────────────────────────────────────────────────────
#
# 한 번도 게시된 적 없는 앱(=초안 앱)은 릴리스를 draft 로만 만들 수 있다.
# completed 로 먼저 시도하고, 초안 앱이라는 응답이 오면 draft 로 내려서 다시 건다.
assign_track() {
  curl -sS -X PUT "$API/edits/$EDIT/tracks/$TRACK" "${AUTH[@]}" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$TRACK" --arg v "$VERSION_CODE" --arg s "$1" \
          '{track: $t, releases: [{versionCodes: [$v], status: $s}]}')"
}

validate_edit() {
  curl -sS -X POST "$API/edits/$EDIT:validate" "${AUTH[@]}" -H 'Content-Length: 0'
}

STATUS=completed
echo "▸ '$TRACK' 트랙에 배정 ($STATUS)"
RESP=$(assign_track "$STATUS")
jq -e '.track' >/dev/null <<<"$RESP" || { echo "트랙 배정 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }

echo "▸ 검증 중"
RESP=$(validate_edit)

if ! jq -e '.id' >/dev/null <<<"$RESP"; then
  MSG=$(jq -r '.error.message // ""' <<<"$RESP")

  if [[ "$MSG" == *"status draft"* ]]; then
    # 아직 게시 이력이 없는 앱 — draft 로 올리고 게시는 Console 에서 사람이 누른다.
    STATUS=draft
    echo "  초안 앱이라 draft 로 전환합니다 (게시는 Console 에서 눌러야 시작됩니다)"
    RESP=$(assign_track "$STATUS")
    jq -e '.track' >/dev/null <<<"$RESP" || { echo "트랙 배정 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }
    RESP=$(validate_edit)
  fi

  jq -e '.id' >/dev/null <<<"$RESP" || { echo "검증 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }
fi

echo "▸ 커밋 중 (여기서부터 되돌릴 수 없습니다)"
RESP=$(curl -sS -X POST "$API/edits/$EDIT:commit" "${AUTH[@]}" -H 'Content-Length: 0')
jq -e '.id' >/dev/null <<<"$RESP" || { echo "커밋 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }

EDIT=""  # 커밋됨 — cleanup 이 지우려 하지 않게
trap - EXIT
echo
echo "완료: $PACKAGE · versionCode $VERSION_CODE · $TRACK 트랙 · $STATUS"
if [[ "$STATUS" == draft ]]; then
  echo "초안으로 올라갔습니다 — Play Console 에서 '검토 후 출시'를 눌러야 테스터에게 갑니다."
else
  echo "테스터 목록은 Play Console 에서 지정해야 배포가 시작됩니다."
fi
