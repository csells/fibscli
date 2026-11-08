# Browser e2e (Playwright)

Drives the **real web build** in a headless Chromium and verifies the main app
paths plus the live FIBS path:

> `/` → `/local` → `/computer?engine=Gary%20Gammon&level=3` → `/fibs` → app
> **autologins** → live bot list renders (real bots, ratings, in-progress games)
> → **logout**

This complements the Dart tests: the widget tests (`test/fibs_play_widget_test`,
`test/fibs_play_state_test`) cover the UI ↔ `FibsState` ↔ board path offline,
and `test/fibs_live_e2e_test.dart` covers live match play. This one proves the
**served web build** renders live FIBS data in an actual browser.

## Run it

From the repo root:

```bash
./tool/browser_e2e/run.sh
```

That script (one clean pass, one FIBS login):

1. reads `fibs_uname`/`fibs_pword` from `.env` (values never printed) and builds
   `build/web` with them baked in via `--dart-define` — the app autologins, so
   no credential is ever typed into a form;
2. fails fast if local `websocat` is listening on `:8080`;
3. uses the hosted Cloudflare Worker bridge at `wss://proxy.playfibs.com/fibs`;
4. enables the e2e-only JS probe with `--dart-define=fibs_e2e_probe=true`;
5. verifies both protocol evidence and sanitized Flutter app state:
   WebSocket frames, completed who-list, app `whoCount > 0`, app `botCount > 0`,
   and clean logged-out state after Logout;
6. serves `build/web` on `:$PORT` (`18088` by default) with an SPA fallback so
   direct clean-path URLs work locally like Firebase Hosting rewrites;
7. installs Playwright the first time, then runs `fibs_e2e.mjs`.

Output (screenshots + video) lands in `tool/browser_e2e/out/` (gitignored).

## FIBS etiquette

This hits the **real, shared** FIBS server. Per `AGENTS.md` ("FIBS testing
etiquette"): one login per run, log out cleanly, iterate selectors/coordinates
offline so the live run is a single pass — don't loop it. The baked-in password
lives only in the local, gitignored `build/web` bundle; never commit a build.

## Complete games against Gary

`computer_games.mjs` drives three complete level-7 games through the rendered
computer-game screen. The read-only `__computerE2EState` probe provides legal
human moves and rendered pointer targets. The driver clicks the actual board,
Roll, dice, cube-acceptance and end-game controls. It never applies a move or
changes game state through the probe. Gary uses the production session-token,
Turnstile and gnubg endpoints. Every failed engine response, page exception,
unavailable-engine banner or stalled board fails the run.

Build the candidate with its read-only probe:

```sh
./build-web.sh --dart-define=computer_e2e_probe=true --no-wasm-dry-run
npm ci --prefix tool/browser_e2e
./tool/browser_e2e/node_modules/.bin/playwright install ffmpeg
```

Serve that build using `spa_server.mjs` on localhost9090 (or forward that port
to the disposable candidate VM). Keep the localhost origin: the existing
publishable key permits it. The BB share's different origin does not authorize
Gary.

The verified Mac browser configuration uses Camoufox156.0.1-beta.36 with
Playwright1.64.0. Browser checks remain real; there are no fabricated challenge
tokens or network mocks. Chromium is also supported and can click the ordinary
visible verification checkbox, but its production challenge may decline automation.

```sh
uv run --with camoufox==0.5.8 python -m camoufox fetch official/156.0.1-beta.36
uv run --with camoufox==0.5.8 python tool/browser_e2e/camoufox_options.py \
  --output /tmp/fibs-browser-options.json
CAMOUFOX_OPTIONS=/tmp/fibs-browser-options.json \
  GAMES=3 node tool/browser_e2e/computer_games.mjs
```

Artifacts in `out/computer/` include screenshots throughout each game, full
browser video, sanitized endpoint/status evidence and completed-game results.
`HEADED=1` opens the Chromium run visibly; `CHROME_BINARY` selects an installed
Chrome for Testing. `BASE_URL`, `OUT` and `GAMES` configure the target, evidence
directory and game count. The test has no FIBS login or live FIBS-server traffic.
The normal local CI gate remains offline; run this production-backed browser
check explicitly after changing the computer-opponent integration.
