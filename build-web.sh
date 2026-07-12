#!/usr/bin/env bash
set -euo pipefail

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_VERSION=$(git rev-parse --short HEAD)
  if [ -n "$(git status --porcelain)" ]; then
    GIT_VERSION="$GIT_VERSION-dirty"
  fi
else
  GIT_VERSION=local
fi

APP_VERSION=${APP_VERSION:-$GIT_VERSION}
ANALYTICS_URL=${ANALYTICS_URL:-https://proxy.playfibs.com/analytics}
ANALYTICS_ENVIRONMENT=${ANALYTICS_ENVIRONMENT:-prod}

# The Gary Gammon opponent (levels 1-7) plays through the hosted gnubg-service.
# Both values are PUBLIC by design: the publishable key is origin-locked (and
# only mints tokens behind a Turnstile challenge) and the sitekey ships in every
# page that renders the widget. Empty values simply leave Gary unavailable, so
# the ladder degrades to Harry Heuristic (level 0).
GNUBG_PUBLISHABLE_KEY=${GNUBG_PUBLISHABLE_KEY:-bg_pk_live_xozWF3ItN5YnP1oxBgyIhh1gkUGfs4UbFUShu0vIYYf}
GNUBG_TURNSTILE_SITEKEY=${GNUBG_TURNSTILE_SITEKEY:-0x4AAAAAAD0Fqs-IyW1ctfqD}
GNUBG_SERVICE_URL=${GNUBG_SERVICE_URL:-}

flutter build web --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=analytics_url="$ANALYTICS_URL" \
  --dart-define=analytics_environment="$ANALYTICS_ENVIRONMENT" \
  --dart-define=app_version="$APP_VERSION" \
  --dart-define=gnubg_publishable_key="$GNUBG_PUBLISHABLE_KEY" \
  --dart-define=gnubg_turnstile_sitekey="$GNUBG_TURNSTILE_SITEKEY" \
  --dart-define=gnubg_service_url="$GNUBG_SERVICE_URL"
