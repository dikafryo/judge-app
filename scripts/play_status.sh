#!/usr/bin/env bash
#
# 플레이에 지금 무엇이 올라가 있는지 읽어서 보여 준다. 아무것도 바꾸지 않는다.
#
#   play_status.sh
#
# 업로드 스크립트의 "성공" 응답만 믿지 않기 위한 것이다. 예전에 아이콘이
# 성공으로 응답받고도 실제로는 0장이었던 적이 있다(24비트 PNG 라 거부됨).
#
set -euo pipefail

PACKAGE="${PLAY_PACKAGE:-kr.sw4u.judge_app}"
LANG_CODE="${PLAY_LANG:-ko-KR}"
SA="${SERVICE_ACCOUNT_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/judge-app/google-service-account.json}"
API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE"

[[ -f "$SA" ]] || { echo "서비스 계정 키를 찾을 수 없습니다: $SA" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq 가 필요합니다." >&2; exit 1; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

EMAIL=$(jq -r .client_email "$SA")
NOW=$(date +%s)
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
CLAIM=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","exp":%s,"iat":%s}' \
    "$EMAIL" "$((NOW + 3600))" "$NOW" | b64url)
SIG=$(printf '%s.%s' "$HEADER" "$CLAIM" | openssl dgst -sha256 -sign <(jq -r .private_key "$SA") | b64url)

TOKEN=$(curl -sS -X POST https://oauth2.googleapis.com/token \
    -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
    --data-urlencode "assertion=${HEADER}.${CLAIM}.${SIG}" | jq -r '.access_token // empty')
[[ -n "$TOKEN" ]] || { echo "액세스 토큰을 받지 못했습니다." >&2; exit 1; }
AUTH=(-H "Authorization: Bearer $TOKEN")

EDIT=$(curl -sS -X POST "$API/edits" "${AUTH[@]}" -H 'Content-Length: 0' | jq -r '.id // empty')
[[ -n "$EDIT" ]] || { echo "편집 세션을 열지 못했습니다." >&2; exit 1; }
trap 'curl -sS -o /dev/null -X DELETE "$API/edits/$EDIT" "${AUTH[@]}" || true' EXIT

echo "▸ 등록정보"
curl -sS "$API/edits/$EDIT/listings" "${AUTH[@]}" \
    | jq -r '.listings[]? | "  \(.language)  \(.title)\n    \(.shortDescription)\n    자세한 설명 \(.fullDescription | length)자"'

echo "▸ 그래픽"
for type in icon featureGraphic phoneScreenshots; do
    n=$(curl -sS "$API/edits/$EDIT/listings/$LANG_CODE/$type" "${AUTH[@]}" | jq '[.images[]?] | length')
    printf '  %-18s %s장\n' "$type" "$n"
done

echo "▸ 트랙"
curl -sS "$API/edits/$EDIT/tracks" "${AUTH[@]}" | jq -r '
    .tracks[]? |
    "  \(.track)\t" + ((.releases // []) | map("\(.name // "-") · versionCode \((.versionCodes // ["-"]) | join(",")) · \(.status)") | join(" / ") | if . == "" then "(없음)" else . end)'
