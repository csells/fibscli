# FIBS Proxy Worker

Cloudflare Worker that bridges the browser app's WebSocket connection to the
FIBS telnet endpoint at `fibs.com:4321`.

This is not a generic TCP proxy. The target is hardcoded to FIBS, and request
host/port parameters are ignored.

## Commands

```sh
npm ci
npm test
npm run check
npm run dev
npx wrangler deploy
```

Deployment requires an authenticated Wrangler session or a Cloudflare API token
with permission to deploy this Worker and bind the Analytics Engine dataset. Run
`npx wrangler whoami` before deploying; if it reports unauthenticated, run
`npx wrangler login` or configure CI with a Cloudflare API token.

The manual GitHub Actions deploy workflow expects these repository settings:

- secret `CLOUDFLARE_ACCOUNT_ID`
- secret `CLOUDFLARE_API_TOKEN`
- variable `FIBS_PROXY_ALLOWED_ORIGINS`

## Routes

- `GET /healthz` returns `ok`.
- `GET /` or `GET /fibs` with `Upgrade: websocket` opens a bridge session.
- Other requests are rejected and never open a TCP connection.

## Configuration

`wrangler.toml` defines:

- `ENVIRONMENT` — `dev`, `staging`, or `prod`.
- `VERSION` — release identifier or git SHA.
- `ALLOWED_ORIGINS` — comma-separated browser origins allowed to open the
  bridge. Empty means origin checks are disabled.
- `FIBS_PROXY_ANALYTICS` — Workers Analytics Engine binding.

Production should set `ENVIRONMENT=prod`, `VERSION` to the release identifier,
and `ALLOWED_ORIGINS` to the deployed Flutter app origin before promoting the
route.

## Privacy

The Worker must not log or emit FIBS payloads. That includes login commands,
passwords, usernames, who-list rows, chat, and game commands. Metrics contain
only operational metadata and aggregate byte/message counts.

## Local Flutter Development

Local Flutter runs can still use `websocat`:

```sh
websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof

flutter run \
  --dart-define=fibs_proxy_host=127.0.0.1 \
  --dart-define=fibs_proxy_port=8080 \
  --dart-define=fibs_proxy_secure=false \
  --dart-define=fibs_proxy_path=
```

This is contributor infrastructure only. App users do not choose a proxy.
