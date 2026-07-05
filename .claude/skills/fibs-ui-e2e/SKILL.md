---
name: fibs-ui-e2e
description: Validate the FIBS Flutter web UI end to end through the hosted Cloudflare WebSocket-to-telnet proxy. Use when asked to test FIBS in the browser, verify the hosted proxy, run browser e2e, validate the bot list, debug "waiting for the who-list", or prove FIBS login/lobby/logout behavior from the UI.
---

# FIBS UI E2E

## Ground Rules

Read `AGENTS.md` first, especially FIBS testing etiquette. Live FIBS testing uses the real shared server.

Do not run repeated live login/logout cycles. Make code and selector changes offline first, then do one clean live pass.

Do not start or rely on local `websocat`. This project validates the hosted proxy at `wss://proxy.playfibs.com/fibs`.

Do not add UI/runtime shortcuts to make the test pass. The app must populate the lobby through `FibsConnection -> CookieMessage -> FibsState` handlers -> `FibsLobby`.

Do not mutate `FibsLobby`, `whoInfos`, or bot-list UI state outside test fakes. If the lobby UI is stale, fix the notifier/data-flow boundary rather than adding a manual refresh path.

Never log or expose credentials, raw FIBS lines, who-list rows, hostnames, emails, chat text, or game commands. Use counts and cookie enum names only.

## Standard Workflow

1. Check local processes:
   - Verify `websocat` is not listening on `:8080`.
   - Stop any stale local static server that would conflict with `:8088`, or use a different port only after updating the e2e command.
2. Confirm `.env` has `fibs_uname` and `fibs_pword`. Do not print the password.
3. Build through `tool/browser_e2e/run.sh`. It must pass `--dart-define=fibs_e2e_probe=true` and use the hosted proxy.
4. Run Playwright through `tool/browser_e2e/fibs_e2e.mjs`.
5. Require all proof layers before saying the FIBS UI works end to end:
   - Hosted proxy WebSocket opened at `proxy.playfibs.com/fibs`.
   - Proxy received frames from FIBS.
   - FIBS who-list completed (`CLIP_WHO_END`) and at least one known bot row appeared at protocol level.
   - The app e2e probe reports `loggedIn`, `connected`, `whoListComplete`, `whoCount > 0`, and `botCount > 0`.
   - The app e2e probe reports logged-out state after Logout: not connected, no who rows, no bot rows, and no in-game board.
   - Browser page errors are empty.
   - The WebSocket closes after Logout.
6. Preserve screenshots and video under `tool/browser_e2e/out/` as artifacts.

## Probe Contract

The e2e-only JS surface is `globalThis.__fibscliE2EState()`. It exists only when the web build sets `--dart-define=fibs_e2e_probe=true`.

Allowed probe fields are sanitized booleans/counts/type names:

- `loggedIn`, `connected`, `autoLoginTried`, `hasUser`
- `whoCount`, `botCount`, `availableBotCount`, `watchableBotCount`
- `savedMatchCount`, `messageCount`
- `savedMatchReadyCount`, `savedMatchBusyCount`, `savedMatchWaitingCount`
- `inGame`, `playing`, `watching`
- `doubleOffered`, `isMyTurn`, `canRoll`, `canMoveNow`
- `activeDice`, `isGameOver`, `didIWin`
- `cookieCount`, `lastCookie`, `whoInfoCookieCount`, `whoListComplete`

Do not expand the probe with usernames, opponent names, raw cookies, crumbs, hostnames, emails, chat, or credentials.

## Failure Triage

If the proxy WebSocket does not open, inspect Worker deployment, custom domain, origin allowlist, and browser console errors.

If the proxy receives no frames, inspect Worker TCP connection metrics and FIBS availability.

If protocol who-list completes but app `whoCount` is zero, inspect `packages/fibscli_lib` parsing and `FibsState` cookie handlers.

If app `whoCount` is nonzero but bot counts are zero, inspect `FibsLobby`/`BotPolicy` classification.

If app counts are correct but the screen still says "Waiting for the who-list", inspect notifier wiring between `FibsState`, `FibsLobby`, and `_BotListView`.

If Logout does not close the WebSocket, inspect `FibsState.logout`, transport close behavior, and the e2e click target.

Report exactly which layer failed. Do not claim end-to-end success from screenshots or WebSocket frames alone.
