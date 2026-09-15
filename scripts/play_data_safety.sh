#!/usr/bin/env bash
#
# 데이터 안전(Data safety) 신고를 플레이에 올린다.
#
#   play_data_safety.sh [--dry-run]
#
# 내용은 store/data-safety.csv 한 곳에만 있다. 구글이 정한 CSV 를 그대로 보낸다
# (applications.dataSafety 는 CSV 본문을 문자열로 받는다).
#
# 주의: 이 API 는 **덮어쓰기**다. 읽어오는 메서드가 없으므로, 올린 뒤 실제 반영은
# Play Console '앱 콘텐츠 → 데이터 안전' 에서 눈으로 확인해야 한다.
#
# CSV 의 질문 ID 목록은 구글이 콘솔에서 내려 주는 템플릿을 따른다. 양식이 바뀌면
# 콘솔에서 새 템플릿을 내려받아 store/data-safety.csv 를 다시 맞춰야 한다.
#
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV="${DATA_SAFETY_CSV:-$ROOT/store/data-safety.csv}"
PACKAGE="${PLAY_PACKAGE:-kr.sw4u.judge_app}"
SA="${SERVICE_ACCOUNT_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/judge-app/google-service-account.json}"

[[ -f "$CSV" ]] || { echo "신고 내용을 찾을 수 없습니다: $CSV" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq 가 필요합니다." >&2; exit 1; }

echo "▸ 신고 내용 ($(basename "$CSV"))"
awk -F, 'NR > 1 && $3 != "" { printf "  %s\t%s\t%s\n", $1, $2, $3 }' "$CSV" | cut -c1-140

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "--dry-run — 확인만 하고 올리지 않습니다."
    exit 0
fi

[[ -f "$SA" ]] || { echo "서비스 계정 키를 찾을 수 없습니다: $SA" >&2; exit 1; }

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

echo "▸ 올리는 중 ($PACKAGE)"
# 성공하면 204 에 본문이 비어 있다. 본문에서 .error 를 찾는 방식으로는 성공을
# 실패로 읽는다 (빈 입력이면 jq 가 아무것도 내놓지 않고 0 으로 끝난다).
# 그래서 HTTP 상태 줄을 따로 받아 그것으로 판정한다.
RESP=$(jq -Rs '{safetyLabels: .}' < "$CSV" | curl -sS -w '\n%{http_code}' -X POST \
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE/dataSafety" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary @-)

CODE="${RESP##*$'\n'}"
BODY="${RESP%$'\n'*}"

if [[ "$CODE" != 2* ]]; then
    echo "실패 (HTTP $CODE):" >&2
    jq -r '.error.message // .' <<<"$BODY" 2>/dev/null || echo "$BODY" >&2
    exit 1
fi

echo
echo "완료 — Play Console '앱 콘텐츠 → 데이터 안전' 에서 반영된 내용을 확인하세요."
