# Cloudflare FIBS WebSocket Bridge

**Status:** Proposed
**Date:** 2026-07-01
**Owner:** csells

## 1. Context

The Flutter web app cannot connect directly to FIBS because browsers cannot open
raw TCP/telnet sockets. Today the app connects to a WebSocket bridge, and local
development uses `websocat`:

```sh
websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof
```

Production needs the same byte-for-byte bridge behavior, but it must be hosted
for users. Backgammon players should open the app and play; they should never be
asked to host, choose, paste, or understand a proxy URL.

Cloudflare Workers Free is a good fit because Workers can accept inbound
WebSocket connections and open outbound TCP sockets with `connect()`:

- https://developers.cloudflare.com/workers/runtime-apis/websockets/
- https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/
- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/workers/platform/limits/

Cloudflare Workers Free cannot run the existing native `websocat` binary as-is.
This plan creates a small first-party Worker package that implements the same
bridge semantics for the one allowed target: `fibs.com:4321`.

## 2. Goals

- Add a first-party monorepo package for a Cloudflare Worker WebSocket-to-TCP
  bridge.
- Hardcode the target to `fibs.com:4321`; never expose arbitrary host or port
  forwarding.
- Make the hosted bridge the default production path for the app.
- Keep proxy choice out of all user-facing UI and user docs.
- Keep local development and tests ergonomic without turning proxy selection
  into an end-user feature.
- Do not log FIBS traffic, credentials, who-list contents, chat, or raw frames.
- Add automated tests for byte forwarding, target locking, close propagation,
  rejected requests, and safe logging.

## 3. Non-goals

- No public generic TCP relay.
- No user-facing "bring your own proxy" option.
- No browser setting, account setting, query parameter, or local storage value
  that changes the proxy endpoint.
- No FIBS protocol parsing in the Worker. The Worker is a transport bridge only.
- No attempt to reuse `websocat` on Cloudflare Free, because Workers Free is not
  a process or container host.

Developer-only test seams are allowed when they are not user-visible:

- Fake transports in Dart tests.
- Local `websocat` for live-development runs.
- Build or deployment configuration for staging and CI.

## 4. Package Shape

Create a new package:

```text
packages/fibs_proxy_worker/
  README.md
  package.json
  tsconfig.json
  vitest.config.ts
  wrangler.toml
  src/
    index.ts
    bridge.ts
    config.ts
    limits.ts
    logging.ts
  test/
    bridge_test.ts
    request_test.ts
    logging_test.ts
```

This is a TypeScript/Wrangler package, not a Dart pub workspace member. The root
`pubspec.yaml` should not add it to `workspace:`. It is still first-party source
owned by this repo.

Recommended package scripts:

```json
{
  "scripts": {
    "check": "tsc --noEmit",
    "test": "vitest run",
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  }
}
```

## 5. Worker Behavior

The Worker accepts only WebSocket upgrade requests on the bridge route:

- `GET /` or `GET /fibs`
- `Upgrade: websocket`
- optional Origin allowlist for the production app origins

All other requests return a plain response:

- `200` for `/healthz`
- `426` for non-WebSocket requests to the bridge route
- `404` for unknown paths

On a valid WebSocket upgrade:

1. Create a `WebSocketPair`.
2. Accept the server-side WebSocket.
3. Open `connect({ hostname: 'fibs.com', port: 4321 })`.
4. Forward browser messages to the TCP writable stream.
5. Forward TCP readable chunks back to the browser WebSocket.
6. Propagate close/error in either direction to the other side.

The bridge should preserve current app expectations:

- Text frames from the app are encoded as UTF-8 bytes to FIBS.
- Binary frames from the browser are forwarded as bytes.
- Bytes from FIBS are sent back as binary frames, matching local `websocat
  --binary` behavior.
- No newline transformation is performed by the Worker. `FibsConnection.send`
  already appends `\n`.

## 6. Limits And Abuse Controls

The first version should be conservative:

- target is compile-time constant `fibs.com:4321`
- maximum WebSocket message size, for example 8 KB
- idle timeout for sockets that have no traffic after connection
- stricter idle timeout before any client data is sent
- clear close codes/reasons for rejected or timed-out sessions

Do not add a user-selectable proxy target to solve capacity. If the shared
proxy reaches a limit, the app should show a service-busy or connection-failed
message and the operator should raise capacity or tune limits.

## 7. Logging And Privacy

The Worker may log only operational metadata:

- connection accepted/rejected
- close code/reason category
- byte counts
- duration
- sanitized error class/message

It must not log:

- raw WebSocket frames
- raw TCP bytes
- FIBS login command lines
- usernames/passwords
- who-list rows
- chat or game commands

Any logging helper should make raw-frame logging awkward by design. Tests should
pin that credential-looking strings are not emitted.

## 8. Analytics And Metrics

The initial plan's logging rules are not enough. The Worker must ship with a
metrics surface that answers usage, reliability, capacity, and abuse questions
without recording user identities or FIBS traffic.

Use two Cloudflare telemetry paths:

- Built-in Workers metrics for platform health: requests, invocation status,
  resource-limit errors, CPU time, wall time, and Worker runtime failures.
- Workers Analytics Engine for bridge-specific events written from Worker code.

Workers Analytics Engine references:

- https://developers.cloudflare.com/analytics/analytics-engine/
- https://developers.cloudflare.com/analytics/analytics-engine/get-started/
- https://developers.cloudflare.com/analytics/analytics-engine/limits/
- https://developers.cloudflare.com/analytics/analytics-engine/pricing/
- https://developers.cloudflare.com/workers/observability/metrics-and-analytics/

### Event Model

Emit structured data points for these event types:

- `bridge_request` — every request to the Worker, including non-WebSocket
  requests.
- `session_start` — accepted WebSocket and attempted TCP connect to FIBS.
- `tcp_connected` — outbound TCP connection to `fibs.com:4321` opened.
- `tcp_connect_failed` — outbound TCP connect failed or timed out.
- `session_close` — session ended, with close side and reason category.
- `session_reject` — request rejected before opening a FIBS TCP connection.
- `limit_hit` — message size, idle timeout, per-client, or global capacity
  guard fired.
- `bridge_error` — unexpected Worker exception or stream error.

Do not emit FIBS usernames, passwords, commands, chat text, raw frames, raw IP
addresses, or complete user-agent strings.

### Dimensions

Keep dimensions low-risk and queryable:

- event type
- deployment environment: `dev`, `staging`, `prod`
- Worker version or git SHA
- route: `/`, `/fibs`, `/healthz`, `unknown`
- request result: `accepted`, `rejected`, `health`, `not_found`, `error`
- reject reason: `not_websocket`, `bad_method`, `bad_origin`,
  `unknown_path`, `capacity`, `oversize`
- close side: `browser`, `fibs`, `worker`, `timeout`, `error`
- close reason category, not raw error text
- Cloudflare colo
- Cloudflare country code, if present
- Origin allowlist category: `allowed`, `missing`, `rejected`
- client kind bucket, if confidently detected: `web`, `test`, `unknown`

Do not store client IP. If unique-user analytics become necessary, add a
separate privacy-reviewed design using a short-lived, salted, non-reversible
bucket or an explicit app-generated anonymous install id. That is not part of
the first implementation.

### Numeric Metrics

Record numeric values as doubles:

- request count
- accepted session count
- rejected session count
- TCP connect latency in milliseconds
- time to first byte from FIBS in milliseconds
- session duration in milliseconds
- browser-to-FIBS message count
- FIBS-to-browser message count
- browser-to-FIBS byte count
- FIBS-to-browser byte count
- close count
- error count
- idle timeout count
- oversize-message count
- estimated historical concurrency, derived from `session_start` and
  `session_close` events

Analytics Engine has limits on blobs, doubles, indexes, and data points per
invocation. Keep the schema compact enough to fit those limits, and write at
bounded lifecycle points rather than on every frame. Aggregate per-session byte
and message counts in memory, then emit them once on close.

Durable Objects are not part of the first implementation. The aggregate usage
and reliability dashboard can be built from lifecycle metrics emitted directly
by the Worker. Add a Durable Object later only if the service needs exact
real-time coordination, such as a global live session counter or shared rate
limit state.

### Dashboards And Queries

Ship a `docs/analytics.md` file in the Worker package with the dashboard fields
and starter SQL queries for:

- sessions per hour/day
- accepted vs rejected sessions
- rejection breakdown by reason
- TCP connect failure rate
- median and p95 TCP connect latency
- median and p95 time to first FIBS byte
- median and p95 session duration
- bytes transferred per direction
- close reason breakdown
- timeout rate
- error rate
- usage by country and colo
- daily peak concurrent sessions when concurrency tracking exists
- free-tier pressure: WebSocket upgrades per day and rejection/error trends

### Tests

Add tests that pin:

- each lifecycle event emits the expected event type and core dimensions
- session close emits aggregate byte/message counters
- rejected requests emit a reason without opening TCP
- metric emission is best-effort and never breaks the bridge
- credentials and raw frame payloads are absent from emitted blobs
- Analytics Engine write failures are swallowed after sanitized logging

## 9. App Integration

The app should continue to route all FIBS traffic through
`packages/fibscli_lib` and `FibsConnection`; the Worker is invisible to the UI.

Implementation tasks:

- Set production build defaults to the hosted Cloudflare Worker endpoint:
  `wss://proxy.playfibs.com/fibs`.
- Keep `FibsState.withTransport` and `FibsState.withTransportFactory` for tests.
- Keep local development support in code or scripts, but document it as
  developer infrastructure, not a user option.
- Remove or rewrite README wording that implies users or deployers need to bring
  their own proxy for normal app use.
- Do not add any UI control, URL parameter, or persisted setting for proxy
  selection.

If `FibsConnection` needs to support a path such as `/fibs`, adjust its URL
builder deliberately:

```dart
// Example shape only; exact API can be chosen during implementation.
FibsConnection(host, port, secure: true, path: '/fibs')
```

The public app should construct it with constants or build-time deployment
values only. The user should never see these details.

## 10. Deployment

Use Cloudflare Workers Free for the initial hosted service.

Suggested deployment names:

- production Worker: `fibs-proxy`
- production route: `https://proxy.playfibs.com/fibs`
- health route: `https://proxy.playfibs.com/healthz`

Deployment tasks:

- Add `wrangler.toml` with explicit compatibility date.
- Add the Analytics Engine dataset binding.
- Configure any Origin allowlist as Worker vars.
- Document `npm install`, `npm test`, `npm run check`, `npx wrangler deploy`.
- Add GitHub Actions checks for the Worker package.
- Add a manual deploy workflow using Cloudflare account/token secrets.

## 11. Testing

Worker package tests:

- rejects non-WebSocket bridge requests
- rejects unknown paths
- accepts WebSocket upgrade on the bridge path
- forwards text browser messages to fake TCP as UTF-8 bytes
- forwards binary browser messages to fake TCP unchanged
- forwards fake TCP chunks back as binary WebSocket messages
- closes TCP when the browser WebSocket closes
- closes WebSocket when TCP closes/errors
- never accepts request-provided host or port values
- never logs raw frame content or credential-like strings
- emits privacy-safe analytics for accept, reject, close, and error paths

App tests:

- `FibsConnection.url` covers secure Worker URL with a path, if path support is
  added.
- Existing fake-transport FIBS tests remain offline.
- Live tests keep their explicit gate and use the hosted Worker endpoint by
  default.

Manual validation:

1. Run Worker locally with `wrangler dev`.
2. Connect with a small WebSocket client and verify the FIBS login prompt.
3. Run the app against the local Worker.
4. Deploy to Cloudflare.
5. Build the web app against the deployed Worker endpoint.
6. Perform one gentle live FIBS login/logout pass.
7. Verify Analytics Engine receives `session_start`, `tcp_connected`, and
   `session_close` events without payload content.

## 12. Rollout

1. Add and test the Worker package.
2. Deploy a private/staging Worker endpoint.
3. Update the Flutter app build defaults for production.
4. Update README and browser e2e docs to describe the hosted bridge.
5. Run offline tests.
6. Run one gated live FIBS validation pass.
7. Promote the Worker endpoint for the public web app.

## 13. Open Decisions

- Exact allowed Origin list.
- Wrangler login or CI API token for the Cloudflare account that owns the
  Worker and Analytics Engine dataset.
- Whether to promote the manual workflow to automatic deployment later.
- Exact Analytics Engine dataset name and retention/export strategy beyond the
  default retention window.
