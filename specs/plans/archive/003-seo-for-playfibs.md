# Plan 003 — SEO for playfibs.com

## Why

playfibs.com is a Flutter CanvasKit app: crawlers see an empty body with two
scripts, a bare `<title>playfibs</title>`, and one meta description. There is
no robots.txt, no sitemap, no Open Graph/Twitter metadata, no structured data,
and no crawlable text. People and bots cannot meaningfully find or preview the
site. The www→apex 301 (single canonical host) already exists.

## Decisions

- **Canonical is statically `https://playfibs.com/` on every route.** The SPA
  fallback serves `index.html` for all paths and the homepage is the only
  content page worth ranking; consolidating every URL variant's signals into
  the apex is correct here, and it avoids per-path HTML rewriting in the site
  worker (rejected: real complexity for a two-route app whose second route is
  legal boilerplate).
- **Sitemap lists only `/`.** Listing `/privacy` while its canonical points at
  `/` would send conflicting signals.
- **Crawlable content lives in `index.html`'s body** (heading, description,
  mode list, links) and is removed on the `flutter-first-frame` event — bots
  and no-JS agents get real text; humans get a styled loading state instead of
  a white flash. A `<noscript>` block covers script-less agents.
- **OG image is a real screenshot** of the landing page at 1200×630, shipped
  as `web/og-image.png` (absolute URL in the tags — scrapers don't resolve
  relative OG paths reliably).
- **JSON-LD**: a truthful `WebApplication` entity (free, GameApplication,
  about Backgammon). No review/rating markup — we have none.

## Work items (red-green TDD)

1. `test/seo_test.dart` pins the whole contract first (red): robots.txt
   directives + sitemap reference; sitemap shape; `lang="en"`; canonical;
   title/description quality bounds; OG + Twitter tags; parseable JSON-LD with
   the right type; crawlable `<h1>` + noscript + first-frame removal hook;
   og-image.png exists with PNG magic bytes and 1200×630 IHDR dimensions.
2. `web/robots.txt`, `web/sitemap.xml`, `web/og-image.png` (screenshot of the
   live landing page), and the `index.html` head/body work to turn it green.
3. Full local gate, rebuild, deploy, live verification: robots/sitemap/og
   image reachable with correct content types; served page carries the tags;
   still exactly one analytics beacon.

## Operator follow-ups (not code; user actions)

- Register the domain in Google Search Console + Bing Webmaster Tools (DNS TXT
  verification) and submit `https://playfibs.com/sitemap.xml`.
- Optionally enable Crawler Hints / IndexNow on the zone.

## Out of scope

- Per-route canonicals/titles (single-content-page app; see Decisions).
- Prerendering or bot-specific rendering (cloaking risk, no content to gain).
- Soft-404 hardening of the SPA fallback (revisit only if Search Console
  flags it).

## Archival note (2026-07-12)

Complete and deployed: robots.txt, sitemap.xml, canonical + title/description,
Open Graph + Twitter cards with a 1200x630 share image, WebApplication JSON-LD,
and crawlable landing content that yields to the app on `flutter-first-frame`
(all pinned by `test/seo_test.dart` and verified live). The operator follow-ups
remain open and are the user's: register the domain in Google Search Console and
Bing Webmaster Tools and submit the sitemap; optionally enable Crawler Hints /
IndexNow on the zone.
