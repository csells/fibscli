#!/usr/bin/env bash
# The full gate, run locally. This is THE CI for this repo: GitHub Actions
# cannot run it, because the app depends on the private csells/gnubg-service
# repo via a pub git dependency and a runner has no credential for it. A
# developer machine does, so the gate lives here and the pre-push hook
# (.githooks/pre-push) enforces it before anything reaches main.
#
#   ./tool/ci.sh          run everything
#   SKIP_E2E=1 git push   push without the hook re-running this (see the hook)
#
# Every check below is fatal. Nothing is excluded: lib/, test/, and every
# packages/ member are first-party code held to the same bar.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step 'Resolving Dart workspace dependencies'
flutter pub get

step 'Format check (whole workspace)'
dart format --output=none --set-exit-if-changed .

step 'Analyze (strict: infos are fatal)'
dart analyze --fatal-infos .

step 'Flutter tests'
flutter test

for worker in fibs_proxy_worker playfibs_site; do
  step "Worker: $worker"
  (
    cd "packages/$worker"
    # `npm ci` is only needed when the lockfile is newer than the install.
    if [ ! -d node_modules ] || [ package-lock.json -nt node_modules ]; then
      npm ci
    fi
    npm run check   # tsc --noEmit
    npm test        # vitest run
  )
done

printf '\n\033[32m\033[1mAll checks passed.\033[0m\n'
