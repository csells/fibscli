# playfibs.com Hosting and Visitor Analytics

Everything public-facing runs on one Cloudflare account: DNS for the
`playfibs.com` zone, the FIBS proxy Worker (`proxy.playfibs.com`), Workers
Analytics Engine, and — since 2026-07-11 — the web app itself.

## Site hosting

`packages/playfibs_site` is a Workers static-assets deployment serving the
release bundle from `build/web`:

- `wrangler.jsonc`: assets directory `../../build/web`, binding `ASSETS`,
  `not_found_handling: single-page-application` (deep app routes fall back to
  `index.html`), `run_worker_first: true`, observability enabled.
- The 12-line handler does exactly one thing beyond asset serving: 301
  `www.playfibs.com` → `playfibs.com` preserving path and query (single
  canonical host).
- Custom domains `playfibs.com` and `www.playfibs.com` are attached in the
  worker config; Cloudflare manages their DNS records and certificates.

Deploy: `./build-web.sh` then `npx wrangler deploy` from the package. There is
no CI deploy — GitHub Actions cannot clone the private `backgammon_ai` pub
dependency, so `flutter build web` only works locally. Firebase Hosting's
default domain (`playfibs-f3c5b.web.app`) remains live as a fallback;
`firebase.json`/`.firebaserc` stay until Cloudflare hosting has proven stable.

## Visitor analytics

Two complementary, both privacy-preserving:

- **Cloudflare Web Analytics** (visitor-level: pageviews, referrers,
  countries, uniques): a static, deferred beacon in `web/index.html` with the
  playfibs.com site token (public by design). Cookieless, no cross-site
  tracking — disclosed on the in-app `/privacy` page. The dashboard-created
  site has `auto_install: true`, but Cloudflare's edge injection does not
  apply to Worker-served HTML, so the static snippet is the effective
  mechanism; deploy verification asserts exactly one beacon in the served
  page (`test/web_index_test.dart` pins the source contract).
- **App-event analytics** (in-app behavior): sanitized events posted to the
  proxy Worker's `/analytics` route into Analytics Engine — see
  `fibs-proxy-worker.md`.
