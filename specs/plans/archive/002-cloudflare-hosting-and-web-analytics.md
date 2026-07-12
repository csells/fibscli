# Plan 002 — Cloudflare hosting for playfibs.com + visitor analytics

## Why

- `playfibs.com` currently does not resolve: the zone's nameservers are Cloudflare
  (required by the `proxy.playfibs.com` Worker custom domain), but the apex/www have
  no DNS records pointing anywhere. The app is only reachable at
  https://playfibs-f3c5b.web.app (Firebase Hosting).
- The account already administers DNS, the FIBS proxy Worker, and Analytics Engine
  on Cloudflare. Moving hosting there consolidates to one vendor, one CLI
  (wrangler), and one deploy pattern, and makes the apex wiring native (Workers
  custom domains) instead of re-creating Firebase's A/TXT verification records.
- The app has first-party sanitized **event** analytics (app → Worker `/analytics`
  → Analytics Engine) but no **visitor** analytics (pageviews, referrers, uniques).
  Cloudflare Web Analytics is free, cookieless, and consistent with the privacy
  page's aggregate-only promise.

## Decisions

- **Workers static assets, not Pages** — Cloudflare's recommended path for new
  static sites; mirrors the existing `packages/fibs_proxy_worker` layout and deploy
  flow (wrangler, vitest, `npm run check`).
- **New workspace package `packages/playfibs_site/`** — worker config + a minimal
  fetch handler whose only logic is `www.playfibs.com` → `playfibs.com` 301
  (path/query preserved); everything else falls through to static assets from
  `build/web` with SPA not-found handling. Custom domains: `playfibs.com` and
  `www.playfibs.com`.
- **Beacon lives statically in `web/index.html`** with the real site token (beacon
  tokens are public by design). Local-dev traffic noise is acceptable and can be
  filtered by hostname in the dashboard; this keeps the build free of injection
  plumbing. The dashboard-created Web Analytics site has `auto_install: true`,
  but Cloudflare's edge injection does not apply to Worker-served HTML (verified
  empirically against the live site), so the static snippet is the effective
  mechanism and there is no double-count. Deploy verification asserts exactly
  one beacon in the served page.
- **Firebase stays up as fallback** during cutover (`playfibs-f3c5b.web.app`).
  Removing `firebase.json`/`.firebaserc` is deliberately deferred until Cloudflare
  hosting has been stable in production.
- **No CI deploy workflow yet** — GitHub Actions cannot resolve the private
  `backgammon_ai` git dependency, so `flutter build web` fails there. App deploys
  stay local (`./build-web.sh && wrangler deploy` from `packages/playfibs_site`)
  until Actions gets access to that repo. Consciously deferred, not forgotten.

## Work items (red-green TDD)

1. **Site worker** (`packages/playfibs_site/`): vitest tests first —
   www→apex 301 preserving path+query, non-www requests served from assets
   (mocked `env.ASSETS`), no caching of the redirect beyond defaults. Then the
   handler + `wrangler.toml` (assets dir `../../build/web`, SPA not-found handling,
   both custom domains). `npm run check` + tests green.
2. **Web Analytics beacon** (`web/index.html`): a Dart test asserting the beacon
   script tag (correct `src`, `defer`, `data-cf-beacon` token JSON) fails first,
   then add the snippet. Requires a Web Analytics site token — wrangler's OAuth
   token lacks the RUM scope, so provision via dashboard or a scoped API token.
3. **Privacy page copy** (`lib/privacy_page.dart`): widget test asserting the
   hosting section names Cloudflare (not Firebase) and discloses Cloudflare Web
   Analytics as cookieless/aggregate fails first, then update the copy.
4. **Docs**: README production-deployment section (firebase deploy → wrangler
   deploy), AGENTS.md if the deploy commands change agent workflow.

## Verification (real artifact)

- `dig playfibs.com` resolves; `curl -I https://playfibs.com` returns 200 with the
  app's index; `curl -I https://www.playfibs.com/foo?x=1` returns 301 to
  `https://playfibs.com/foo?x=1`.
- Browser screenshot of https://playfibs.com landing page.
- Page source contains the beacon script; proxy CORS accepts
  `Origin: https://playfibs.com` (should already — origin string unchanged).
- Full local CI gate: `dart format --set-exit-if-changed .`,
  `dart analyze --fatal-infos .`, `flutter test`.

## Out of scope

- gnubg-service build flags (updated gnubg API is in flight separately).
- Decommissioning Firebase and the CI deploy workflow (see Decisions).

## Archival note (2026-07-11)

Complete — verified 100% by the fresh-eyes gap analysis in
`specs/gaps/2026-07-11-plans-001-002.md`, including live checks of the apex,
the www redirect, the SPA fallback, the beacon (exactly one, token matching
source), and the deployed privacy copy. The two deferrals recorded under
Decisions (no CI deploy workflow until Actions can clone `backgammon_ai`;
Firebase decommission after Cloudflare hosting proves stable) remain in force.
