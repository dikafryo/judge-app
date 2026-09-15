#!/usr/bin/env bash
#
# 스토어 등록정보(문안 + 그래픽)를 플레이에 올린다.
#
#   play_listing.sh [--dry-run]
#
# 문안은 store/LISTING.md 의 코드블록에서 그대로 읽는다 — 문서와 실제 등록정보가
# 어긋나지 않게 하려는 것이다. 문안을 고칠 곳은 LISTING.md 한 곳뿐이다.
#
# 이미지는 store/ 에서 가져온다.
#   icon-512.png · feature-graphic-1024x500.png · screenshot-*.jpg
#
# 주의: 이미지 업로드는 해당 종류를 **통째로 교체**한다(먼저 지우고 다시 올린다).
# 스크린샷은 파일 이름 순서 그대로 스토어에 노출된다.
#
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORE="$ROOT/store"
LISTING="$STORE/LISTING.md"
LANG_CODE="${PLAY_LANG:-ko-KR}"
PACKAGE="${PLAY_PACKAGE:-kr.sw4u.judge_app}"
# 서명 키(key.properties)와 같은 자리에 둔다. 저장소 바깥이라 커밋될 일이 없다.
SA="${SERVICE_ACCOUNT_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/judge-app/google-service-account.json}"

API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE"
UPLOAD="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE"

[[ -f "$LISTING" ]] || { echo "등록정보 문서가 없습니다: $LISTING" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq 가 필요합니다." >&2; exit 1; }

# ── LISTING.md 에서 문안 뽑기 ────────────────────────────────────────────────
# "## <제목>" 다음에 오는 첫 ``` 블록의 내용을 그대로 가져온다.
extract_block() {
    awk -v want="$1" '
        $0 ~ "^## " want { found = 1; next }
        found && /^```/  { inblock = !inblock; if (!inblock) exit; next }
        inblock          { print }
    ' "$LISTING"
}

TITLE=$(extract_block "앱 이름")
SHORT=$(extract_block "간단한 설명")
FULL=$(extract_block "자세한 설명")

[[ -n "$TITLE" && -n "$SHORT" && -n "$FULL" ]] \
    || { echo "LISTING.md 에서 문안을 읽지 못했습니다." >&2; exit 1; }

# 플레이 상한 — 넘으면 API 가 거절하므로 미리 잡는다
check_len() {
    local label="$1" text="$2" max="$3" n
    n=$(printf '%s' "$text" | wc -m | tr -d ' ')
    (( n <= max )) || { echo "$label 이 $max 자를 넘습니다 ($n 자)." >&2; exit 1; }
    printf '  %-12s %4d / %d\n' "$label" "$n" "$max"
}

echo "▸ 문안 확인"
check_len "앱 이름" "$TITLE" 30
check_len "간단한 설명" "$SHORT" 80
check_len "자세한 설명" "$FULL" 4000

# macOS 기본 bash 는 3.2 라 mapfile 이 없다. 이식성 있게 채운다.
SHOTS=()
while IFS= read -r shot; do
    SHOTS+=("$shot")
done < <(ls -1 "$STORE"/screenshot-*.jpg 2>/dev/null | sort)

(( ${#SHOTS[@]} >= 2 )) || { echo "스크린샷이 2장 이상이어야 합니다." >&2; exit 1; }

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "--dry-run — 확인만 하고 올리지 않습니다."
    echo "  아이콘        $(basename "$STORE/icon-512.png")"
    echo "  그래픽 이미지  $(basename "$STORE/feature-graphic-1024x500.png")"
    printf '  스크린샷      %s\n' "${SHOTS[@]##*/}"
    exit 0
fi

[[ -f "$SA" ]] || { echo "서비스 계정 키를 찾을 수 없습니다: $SA" >&2; exit 1; }

# ── 액세스 토큰 ──────────────────────────────────────────────────────────────
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

# ── 편집 세션 ────────────────────────────────────────────────────────────────
EDIT=""
cleanup() { [[ -n "$EDIT" ]] && curl -sS -o /dev/null -X DELETE "$API/edits/$EDIT" "${AUTH[@]}" || true; }

echo "▸ 편집 세션 여는 중 ($PACKAGE · $LANG_CODE)"
RESP=$(curl -sS -X POST "$API/edits" "${AUTH[@]}" -H 'Content-Length: 0')
EDIT=$(jq -r '.id // empty' <<<"$RESP")
[[ -n "$EDIT" ]] || { echo "편집 세션 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }
trap cleanup EXIT

# ── 문안 ─────────────────────────────────────────────────────────────────────
echo "▸ 문안 올리는 중"
RESP=$(curl -sS -X PUT "$API/edits/$EDIT/listings/$LANG_CODE" "${AUTH[@]}" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg l "$LANG_CODE" --arg t "$TITLE" --arg s "$SHORT" --arg f "$FULL" \
          '{language: $l, title: $t, shortDescription: $s, fullDescription: $f}')")
jq -e '.title' >/dev/null <<<"$RESP" || { echo "문안 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }

# ── 이미지 ───────────────────────────────────────────────────────────────────
# 종류마다 먼저 비우고 다시 올린다. 안 그러면 예전 것이 남아 섞인다.
upload_images() {
    local type="$1"; shift
    local files=("$@") f mime resp

    curl -sS -o /dev/null -X DELETE "$API/edits/$EDIT/listings/$LANG_CODE/$type" "${AUTH[@]}"

    for f in "${files[@]}"; do
        case "$f" in
            *.png) mime=image/png ;;
            *)     mime=image/jpeg ;;
        esac

        resp=$(curl -sS -X POST "$UPLOAD/edits/$EDIT/listings/$LANG_CODE/$type?uploadType=media" \
            "${AUTH[@]}" -H "Content-Type: $mime" --data-binary "@$f")

        jq -e '.image.id' >/dev/null <<<"$resp" \
            || { echo "이미지 실패 ($(basename "$f")):" >&2; jq -r '.error.message // .' <<<"$resp" >&2; exit 1; }
        echo "    $(basename "$f")"
    done
}

echo "▸ 아이콘"
upload_images icon "$STORE/icon-512.png"

echo "▸ 그래픽 이미지"
upload_images featureGraphic "$STORE/feature-graphic-1024x500.png"

echo "▸ 스크린샷"
upload_images phoneScreenshots "${SHOTS[@]}"

# ── 검증 후 커밋 ─────────────────────────────────────────────────────────────
echo "▸ 검증 중"
RESP=$(curl -sS -X POST "$API/edits/$EDIT:validate" "${AUTH[@]}" -H 'Content-Length: 0')
jq -e '.id' >/dev/null <<<"$RESP" || { echo "검증 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }

echo "▸ 커밋 중"
RESP=$(curl -sS -X POST "$API/edits/$EDIT:commit" "${AUTH[@]}" -H 'Content-Length: 0')
jq -e '.id' >/dev/null <<<"$RESP" || { echo "커밋 실패:" >&2; jq -r '.error.message // .' <<<"$RESP" >&2; exit 1; }

EDIT=""
trap - EXIT
echo
echo "완료: $LANG_CODE 등록정보 · 스크린샷 ${#SHOTS[@]}장"
