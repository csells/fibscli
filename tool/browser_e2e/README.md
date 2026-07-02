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
