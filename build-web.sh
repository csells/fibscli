#!/usr/bin/env bash
set -euo pipefail

APP_VERSION=${APP_VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}
ANALYTICS_URL=${ANALYTICS_URL:-https://proxy.playfibs.com/analytics}
ANALYTICS_ENVIRONMENT=${ANALYTICS_ENVIRONMENT:-prod}

flutter build web --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=analytics_url="$ANALYTICS_URL" \
  --dart-define=analytics_environment="$ANALYTICS_ENVIRONMENT" \
  --dart-define=app_version="$APP_VERSION"
