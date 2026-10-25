#!/bin/bash
# Screenshot a car page with sample data, in light + dark, at three car sizes.
# Usage: tool/shoot.sh <page.html> <outdir> [--photo <img>]
# Writes <outdir>/<page>[-photo]-<w>x<h>-<theme>.png. The shipped page is not modified.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="$1"; OUT="$2"; PHOTO=""
if [ "${3:-}" = "--photo" ]; then PHOTO="$4"; fi
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Own throwaway profile: never touch (or lock) the owner's everyday Chrome profile.
PROFILE="$(mktemp -d "${TMPDIR:-/tmp}/dashmate-shot-chrome.XXXXXX")"
trap 'rm -rf "$PROFILE"' EXIT
ASSETS="$ROOT/android/app/src/main/assets"
NAME="$(basename "$PAGE" .html)"
SUFFIX=""; if [ -n "$PHOTO" ]; then SUFFIX="-photo"; fi
TMP="$ROOT/build/shots/tmp/$NAME$SUFFIX"
mkdir -p "$OUT" "$TMP"
OUT="$(cd "$OUT" && pwd)"
cp -R "$ASSETS/." "$TMP/"
STATE="$(cat "$ROOT/tool/fixtures/state.json")"
TAG=""
if [ -n "$PHOTO" ]; then
  cp "$PHOTO" "$TMP/test-photo.jpg"; TAG="-photo"
  STATE="$(python3 -c 'import json,sys; s=json.loads(sys.argv[1]); s["bg"]={"mode":"photo","dim":0.35,"url":"test-photo.jpg"}; print(json.dumps(s))' "$STATE")"
fi
# Push the sample state once the page has loaded (like the app does), then once more for late renders.
python3 - "$TMP/$NAME.html" "$STATE" <<'EOF'
import sys
p, state = sys.argv[1], sys.argv[2]
src = open(p, encoding="utf-8").read()
inj = "<script>window.addEventListener('load',function(){var s=%s;function go(){if(window.ddUpdate)ddUpdate(JSON.parse(JSON.stringify(s)));}go();setTimeout(go,400);});</script>" % state
src = src.replace("</body>", inj + "</body>") if "</body>" in src else src + inj
open(p, "w", encoding="utf-8").write(src)
EOF
for size in 800x480 1280x720 720x1280; do
  for theme in light dark; do
    "$CHROME" --headless=new --user-data-dir="$PROFILE" --no-first-run --no-default-browser-check --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --allow-file-access-from-files --virtual-time-budget=3000 --window-size="${size/x/,}" \
      --screenshot="$OUT/$NAME$TAG-$size-$theme.png" "file://$TMP/$NAME.html?theme=$theme" >/dev/null 2>&1
  done
done
ls "$OUT" | grep "^$NAME$TAG-" | wc -l | xargs echo "screenshots:"
