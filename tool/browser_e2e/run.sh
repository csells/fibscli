#!/usr/bin/env bash
# One-shot browser e2e of the FIBS web client: build the web app with the FIBS
# credentials baked in (from .env, never echoed), bring up the websocat proxy
# and a static server, then drive it once with Playwright (single FIBS login).
#
# Usage (from repo root):  ./tool/browser_e2e/run.sh
#
# Honors FIBS etiquette: exactly one login per run; tears down what it started.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

PORT=8088
HERE=tool/browser_e2e
started_proxy=""
server_pid=""

cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
  [ -n "$started_proxy" ] && kill "$started_proxy" 2>/dev/null || true
}
trap cleanup EXIT

# --- credentials from .env (values never printed) ---------------------------
U=$(grep -i '^fibs_uname[ ]*=' .env | head -1 | sed -E 's/^[^=]*=[ ]*//; s/^["'\'']//; s/["'\'']$//')
P=$(grep -i '^fibs_pword[ ]*=' .env | head -1 | sed -E 's/^[^=]*=[ ]*//; s/^["'\'']//; s/["'\'']$//')
[ -n "$U" ] && [ -n "$P" ] || { echo "missing fibs_uname/fibs_pword in .env"; exit 1; }
echo "building web for user=$U (password hidden)"

flutter build web --release \
  --dart-define=fibs_uname="$U" --dart-define=fibs_pword="$P" >/dev/null

# --- websocat proxy (start only if not already up) --------------------------
if ! lsof -nP -iTCP:8080 -sTCP:LISTEN 2>/dev/null | grep -q websocat; then
  echo "starting websocat proxy on :8080"
  websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof &
  started_proxy=$!
  sleep 1
fi

# --- static server for build/web --------------------------------------------
( cd build/web && python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
server_pid=$!
sleep 1

# --- playwright (install once) + run ----------------------------------------
if [ ! -d "$HERE/node_modules/playwright" ]; then
  echo "installing playwright (one-time)"
  ( cd "$HERE" && npm init -y >/dev/null 2>&1 && npm install playwright >/dev/null 2>&1 )
fi

echo "running browser e2e..."
( cd "$HERE" && BASE_URL="http://localhost:$PORT" OUT=out node fibs_e2e.mjs )
echo "done — see $HERE/out/"
