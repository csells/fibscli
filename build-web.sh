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

flutter build web --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=analytics_url="$ANALYTICS_URL" \
  --dart-define=analytics_environment="$ANALYTICS_ENVIRONMENT" \
  --dart-define=app_version="$APP_VERSION"
