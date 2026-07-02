#!/usr/bin/env bash
# One-shot browser e2e of the served Flutter web app: build with FIBS
# credentials baked in (from .env, never echoed), serve it locally, then drive
# local play, AI play, and one FIBS login through the hosted proxy.
#
# Usage (from repo root):  ./tool/browser_e2e/run.sh
#
# Honors FIBS etiquette: exactly one login per run; tears down what it started.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
One-shot browser e2e of the served Flutter web app.

Usage (from repo root): ./tool/browser_e2e/run.sh

Builds with FIBS credentials from .env, serves build/web with SPA path
fallback, then drives /, /local, /computer, and one live /fibs login/logout.
USAGE
  exit 0
fi

PORT=${PORT:-18088}
HERE=tool/browser_e2e
server_pid=""

cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

# --- credentials from .env (values never printed) ---------------------------
U=$(grep -i '^fibs_uname[ ]*=' .env | head -1 | sed -E 's/^[^=]*=[ ]*//; s/^["'\'']//; s/["'\'']$//')
P=$(grep -i '^fibs_pword[ ]*=' .env | head -1 | sed -E 's/^[^=]*=[ ]*//; s/^["'\'']//; s/["'\'']$//')
[ -n "$U" ] && [ -n "$P" ] || { echo "missing fibs_uname/fibs_pword in .env"; exit 1; }
echo "building web for user=$U (password hidden)"

if lsof -nP -iTCP:8080 -sTCP:LISTEN 2>/dev/null | grep -q websocat; then
  echo "websocat is running on :8080; stop it before hosted-proxy e2e" >&2
  exit 1
fi
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "port :$PORT is already in use; set PORT to a free port" >&2
  exit 1
fi

flutter build web --release \
  --dart-define=fibs_uname="$U" \
  --dart-define=fibs_pword="$P" \
  --dart-define=fibs_e2e_probe=true \
  --dart-define=analytics_url=https://proxy.playfibs.com/analytics \
  --dart-define=analytics_environment=e2e \
  --dart-define=app_version=e2e-local >/dev/null

# --- static server for build/web --------------------------------------------
node "$HERE/spa_server.mjs" "$PORT" build/web >/dev/null 2>&1 &
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
