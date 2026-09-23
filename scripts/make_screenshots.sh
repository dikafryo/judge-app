#!/usr/bin/env bash
#
# 플레이 스크린샷을 앱 화면 렌더링으로 만든다 (실기기 불필요).
#
#   scripts/make_screenshots.sh
#
# test/store_screenshots_test.dart 를 SHOTS=true 로 돌려 store/screenshot-N.png 를 굽고,
# play_listing.sh 가 읽는 형식(JPEG) 으로 바꾼다. 이전 JPEG 은 덮어쓴다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/home/dikafryo/flutter/bin/flutter}"

cd "$ROOT"
"$FLUTTER_BIN" test --dart-define=SHOTS=true test/store_screenshots_test.dart

python3 - <<'PY'
from PIL import Image
import glob, os
for png in sorted(glob.glob('store/screenshot-*.png')):
    jpg = png[:-4] + '.jpg'
    Image.open(png).convert('RGB').save(jpg, quality=92, optimize=True)
    os.remove(png)
    print(jpg, Image.open(jpg).size)
PY
