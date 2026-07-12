# FIBS Proxy Worker

`packages/fibs_proxy_worker` is the Cloudflare Worker that bridges browser
WebSockets to FIBS's telnet socket. It is the only way the web app reaches
FIBS: browsers cannot open raw TCP, so `FibsConnection` (in
`packages/fibscli_lib`) speaks WebSocket to `wss://proxy.playfibs.com/fibs` and
the Worker relays bytes to `fibs.com:4321`. It is a transport bridge only — no
FIBS protocol parsing happens in the Worker.

## Routes

- `GET /` and `GET /fibs` with `Upgrade: websocket` — the bridge
  (`src/config.ts` `BRIDGE_PATHS`).
- `GET /healthz` — plain 200 `ok`, never opens a FIBS connection.
- `POST /analytics` — sanitized app-event ingestion from the Flutter app.
- Anything else — 404 `unknown_path`; non-GET to the bridge — 405 `bad_method`;
  bridge route without upgrade — 426 `not_websocket`.

## Target locking and origins

The TCP target is the compile-time constant `FIBS_TARGET` (`src/config.ts`);
no request-supplied host, port, path, or query is ever honored. Browser
`Origin` headers are checked against the `ALLOWED_ORIGINS` var
(comma-separated); the check is fail-closed — an empty allowlist rejects every
browser origin with 403 `bad_origin` before any socket work. Production origins
are `https://playfibs.com`, `https://playfibs-f3c5b.web.app`, and the local
dev/e2e ports (9090, 18088, 8088).

## Forwarding semantics (websocat --binary parity)

Browser text frames are UTF-8-encoded to bytes; browser binary frames pass
through unchanged; FIBS bytes return as binary WebSocket frames. No newline
transformation on any path — `FibsConnection.send` appends `\n` itself.
Close/error propagates in both directions.

## Limits and close codes

- Message size: 8 KB (`MAX_MESSAGE_BYTES`), enforced before the TCP write;
  oversize closes 1009 `oversize`.
- Idle timeout: 10 min once client data has flowed; a stricter 30 s window
  applies before the first client byte (FIBS banner traffic does not extend
  it). Timeout closes 1001 `idle_timeout`.
- Other closes: 1000 `tcp_eof`, 1011 `websocket_error` / `bridge_error` /
  `tcp_connect_failed`.

## Privacy invariants

Logging (`src/logging.ts`) and Analytics Engine emission carry operational
metadata only: routes, categories, counts, durations, error class names. Raw
frames, TCP bytes, credentials, who-list rows, chat, and game commands are
never logged or emitted; `logging_test.ts` pins this by driving a real login
and asserting the secrets appear nowhere. Client IPs and full user-agents are
never stored.

## Analytics

`[[analytics_engine_datasets]]` binds `FIBS_PROXY_ANALYTICS` →
`fibs_proxy_events`. Eight lifecycle event types (`bridge_request`,
`session_start`, `tcp_connected`, `tcp_connect_failed`, `session_close`,
`session_reject`, `limit_hit`, `bridge_error`) with the low-risk dimension set
(env, version, route, result, reject reason, close side/reason, colo, country,
origin category, client kind). Per-session byte/message counters aggregate in
memory and emit once on close — never per frame. Emission is best-effort: a
throwing `writeDataPoint` never breaks the bridge. Dashboard fields and starter
SQL live in `packages/fibs_proxy_worker/docs/analytics.md`.

## Deployment

Manual only: the `deploy-fibs-proxy-worker.yml` GitHub Actions workflow
(`workflow_dispatch`, Cloudflare secrets, hard-fails on an empty origin list)
or a local `npx wrangler deploy --var ...` with the same vars. CI (`ci.yml`)
gates the package with `tsc --noEmit` + vitest on every push/PR. The app-side
integration points are `FibsConnection`'s `path` support and the four
`--dart-define` proxy seams in `lib/fibs_state.dart` — developer infrastructure
only; no user-facing proxy selection exists anywhere.
