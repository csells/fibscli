# Plan 004 — gnubg-service computer opponent (replace backgammon_ai)

## Why

The `backgammon_ai` git dependency is being removed. Its replacement is the
gnubg-service's **calibrated leveled opponent**, consumed through the
`gnubg_service` Flutter package (git dep on `csells/gnubg-service`,
`packages/gnubg_service`), which owns the generated OpenAPI client and the
attested session-token lifecycle (publishable key + Turnstile → `bg_tk_`
tokens). The old `HttpGnubgClient` targets endpoints that no longer exist.

## Decisions (grilled 2026-07-12, all user-resolved)

1. **Gary Gammon is the service's `play*` opponent, N=7, 1:1.** Picker levels
   1–7 map verbatim to service levels (novice → world-class) via
   `playMove`/`playCube`/`playTake`/`playResign`, with a fresh random
   per-match seed (`Random().nextInt(1 << 32)`) so weakened levels (1–4) vary
   between matches while staying internally consistent. Not `analyze*`+plies —
   the handoff doc's analyze-based mapping predates the play surface and is
   superseded.
2. **Level 0 is Harry Heuristic** — the offline `PubevalAiPlayer`, caption
   "ELO 1450 · offline". Always available on every platform.
3. **Unavailable Gary levels render grayed out, not hidden.** On non-web
   builds and web builds without a publishable key, levels 1–7 are visible but
   disabled with an "online opponent — web only" style caption; Harry stays
   playable. (Gary is web-only: the token mint needs a browser Origin and a
   browser-hosted Turnstile challenge.)
4. **Labels**: landing section heading "Play Against the Computer"; level 0
   "Harry Heuristic", levels 1–7 "Gary Gammon" with the calibrated tier names
   (novice, beginner, casual, intermediate, advanced, expert, world-class);
   registered factory name "Computer" (shows in the opponent picker, prefs,
   and the /computer route).
5. **Production is wired in this session.** The vault's `bg_pk_live…` key
   already allow-lists `https://playfibs.com` and `http://localhost:9090`
   (probed 2026-07-12); the one missing piece is adding `playfibs.com` to the
   `gnubg api.gammon.guru tokens` Turnstile widget's domains (Cloudflare API
   via vault token, dashboard fallback). build-web.sh bakes the key and
   sitekey (`0x4AAAAAAD0Fqs-IyW1ctfqD`) as dart-defines. Automated
   verification runs against a **local Docker engine** with Cloudflare's
   always-pass test Turnstile pair on fibscli's pinned :9090 (real Turnstile
   rejects automated browsers by design); the production sanity game is one
   human click-test.
6. **CI + push-to-main auto-deploy are in scope.** gnubg-service is private,
   so Actions needs a fine-grained PAT (contents:read on csells/gnubg-service)
   — user mints it later; workflows land now and CI turns green when the
   secret exists. The Cloudflare API token secret is set from the vault. The
   deploy workflow: push to main → full gate → `./build-web.sh` →
   `wrangler deploy` of `packages/playfibs_site`.

## Architectural constraints (from the handoff, still binding)

- `packages/bg_engine` stays pure Dart (no Flutter). `gnubg_service` depends
  on Flutter, so the session-backed client lives in `lib/` (app layer).
- Never fabricate a gnubg decision: the adapter matches the service's hops
  against locally-enumerated legal turns and throws
  `GnubgUnavailableException` on any mismatch or transport failure.
- Never hand-edit the package's generated code.
- Turnstile attestation context comes from `App.navigatorKey.currentContext`
  resolved at mint time (mints can happen ~an hour into a game).
- The seam change: the old analysis-shaped `GnubgClient` (ranked moves) is
  replaced by a play-shaped seam (single leveled decision per call, plus
  take/resign responses); `HttpGnubgClient` and its dead-endpoint tests are
  deleted.

## Work items (red-green TDD)

1. Remove `backgammon_ai` (pubspec, `lib/backgammon_ai_player.dart`, wiring,
   tests); add the `gnubg_service` git dep.
2. bg_engine: replace the analysis seam with the play-shaped seam + adapter
   (level, seed, take/resign) with unit tests; export `gnubg_id.dart`; delete
   `http_gnubg_client.dart` + its test.
3. App layer: `SessionGnubgClient` over `GnubgSession` (MockClient-tested:
   token flow, GNUBG id building, response mapping).
4. "Computer" factory: level 0 → Harry, 1–7 → Gary(level, per-match seed);
   grayed-out unavailable levels; landing page + picker + route/prefs updates;
   SEO static-content copy update.
5. build-web.sh defines + Turnstile widget domain addition + deploy.
6. CI dep-auth step + `deploy-playfibs-site.yml`; Cloudflare secret from
   vault; document the PAT the user owes.
7. Verification: local Docker engine on :9090 test pair — full game vs Gary in
   the real browser artifact (token mint visible in Network tab, then
   `GET /v1/play/*` under `Bearer bg_tk_…`); whole-workspace gate green.

## What verification found (both fixed, both pinned by tests)

1. **Turnstile attestation context.** `turnstileAttest` resolves an `Overlay`
   (hidden challenge) and, when Cloudflare escalates, a `Navigator`
   (`showDialog`) — both by ANCESTOR lookup. The router's Navigator builds its
   Overlay as a *child*, so `App.navigatorKey.currentContext` has neither, and a
   context above the router (a custom app-level Overlay) has the Overlay but no
   Navigator. Fix: a `ShellRoute` wrapping every route keys an app-lifetime
   subtree *inside* the navigator; `App.turnstileContext` reads it.
   (`test/turnstile_overlay_host_test.dart`.)
2. **Per-match seed on the web.** `Random().nextInt(1 << 32)` wraps to
   `nextInt(0)` on JS numbers and throws. Fix: `nextInt(0x40000000)`.

## Verified

- Automated, against a local engine (Docker + Cloudflare's always-pass test
  Turnstile pair) on the pinned port 9090: a real game vs Gary produced
  `POST /v1/token` → 200 (one mint) followed by `GET /v1/play/resign` and
  `GET /v1/play/move` → 200, each carrying `Authorization: Bearer bg_tk_…`,
  the level, and the per-match seed; Gary's move applied on the board (pip
  count 167 → 160).
- Against the **hosted** service, the flow reaches the Turnstile challenge and
  Cloudflare escalates to the visible "Confirming you are human" dialog —
  the documented, intended response to an automated browser. Production
  therefore needs one human sanity game.
- Whole-workspace gate: `dart format`, `dart analyze --fatal-infos`,
  `flutter test` (533) all green.

## Hand-offs / follow-ups

- **User (blocking CI + auto-deploy):** mint a fine-grained GitHub PAT with
  `contents: read` on `csells/gnubg-service` and add it as the repo secret
  `GNUBG_SERVICE_TOKEN` (`gh secret set GNUBG_SERVICE_TOKEN`). Until then both
  workflows fail at `pub get` — the private dependency cannot be cloned.
  `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` are already set from the
  vault.
- **User:** one human game vs Gary on https://playfibs.com (automation cannot
  pass Turnstile by design).
- Done service-side: `playfibs.com` + `www.playfibs.com` added to the gnubg
  Turnstile widget's domains; the publishable key already allow-listed
  `https://playfibs.com`.

## Archival note (2026-07-12)

Complete and deployed. `specs/handoff-gnubg-service-package.md` (the prompt this
plan was written from) is archived alongside it: it was written before the
service's `play*` surface existed, so parts of it are now **wrong** — it
prescribes `analyze*` + plies for the opponent, and a `navigatorKey` context for
the Turnstile attestation. Both were superseded during implementation (see "What
verification found"). Read this plan, not the handoff, for what was actually
built; the lasting design lives in `specs/architecture/game-modes-and-ai-players.md`
and the ADR log.
