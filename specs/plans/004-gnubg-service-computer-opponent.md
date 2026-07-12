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

## Hand-offs / follow-ups

- User: mint the fine-grained PAT and `gh secret set` it (exact command in the
  session report); one human production sanity game on playfibs.com.
