# fibscli
An eventual [FIBS](http://fibs.com) client written in Flutter and hosted on the web.

# status
The app works both as a stand-alone backgammon game (single-player and vs.
computer) **and** as a working FIBS client — account creation, login, live bot
list, watch, and tap-to-move play against bots on fibs.com. Browser builds reach
FIBS through the hosted Cloudflare Worker bridge in `packages/fibs_proxy_worker`.

# screenshot
![screenshot](readme/screenshot.png)

You can try it live here: https://playfibs.com/

It works on desktop and mobile form factors.

All of the FIBS networking and bridge code now lives **in this repo** as
first-party source: `packages/fibscli_lib` for the Dart FIBS client and
`packages/fibs_proxy_worker` for the hosted WebSocket-to-telnet bridge. This repo
owns 100% of its source — there is no external upstream and nothing to sync to.

# FIBS development
The production web app uses the hosted Cloudflare Worker bridge:
`wss://proxy.playfibs.com/fibs`.

Local development can still run a developer-only
[websocat](https://github.com/vi/websocat) bridge. This is for contributors and
tests only; app users do not choose or provide a proxy.

If running JIBS locally, then configure websocat like this:

```sh
$ websocat --binary ws-l:127.0.0.1:8080 tcp:127.0.0.1:4321 --exit-on-eof -v
```

If running against fibs.com, then configure webtelnet like this:

```sh
$ websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof -v
```

Now running fibscli will use a websocket on port 8080 of the localhost to connect to either JIBS or FIBS as appropriate.

Run the Flutter app against the local development bridge with compile-time
developer overrides:

```sh
$ flutter run \
    --dart-define=fibs_proxy_host=127.0.0.1 \
    --dart-define=fibs_proxy_port=8080 \
    --dart-define=fibs_proxy_secure=false \
    --dart-define=fibs_proxy_path=
```

The Cloudflare Worker bridge has its own package:

```sh
$ cd packages/fibs_proxy_worker
$ npm ci
$ npm test
$ npm run check
$ npx wrangler whoami   # must be authenticated before deploy
$ npx wrangler deploy
```

## Production build & deployment

Build the release web bundle:

```sh
$ ./build-web.sh
```

The output in `build/web` is a static bundle, served at https://playfibs.com by
the `playfibs-site` Cloudflare Worker (`packages/playfibs_site`): static assets
with SPA fallback plus a www→apex redirect, attached to the `playfibs.com` and
`www.playfibs.com` custom domains.

**Every push to `main` deploys automatically** (`.github/workflows/deploy-playfibs-site.yml`:
full gate → `./build-web.sh` → `wrangler deploy`). To deploy by hand:

```sh
$ ./build-web.sh
$ cd packages/playfibs_site
$ npm ci
$ npm run check && npm test
$ npx wrangler deploy
```

CI and the deploy workflow both need `GNUBG_SERVICE_TOKEN` (a fine-grained PAT
with `contents: read` on the private `csells/gnubg-service` repo) to resolve the
`gnubg_service` git dependency, plus `CLOUDFLARE_API_TOKEN` /
`CLOUDFLARE_ACCOUNT_ID` to deploy.

To play FIBS from a deployed build, the app uses the hosted Cloudflare Worker
bridge. Users do not configure the bridge; it is app infrastructure. The
bridge's production `ALLOWED_ORIGINS` must include `https://playfibs.com` (see
`.github/workflows/deploy-fibs-proxy-worker.yml`).

`build-web.sh` enables sanitized app analytics by default:

- `ANALYTICS_URL` defaults to `https://proxy.playfibs.com/analytics`.
- `ANALYTICS_ENVIRONMENT` defaults to `prod`.
- `APP_VERSION` defaults to the current git SHA.
- A dirty worktree appends `-dirty` to `APP_VERSION`.

Set `ANALYTICS_URL=` to disable app analytics for an ad hoc release build.
The site also carries a Cloudflare Web Analytics beacon (cookieless visitor
analytics) in `web/index.html`. The public app includes a `/privacy` page
describing the Cloudflare hosting and proxy, FIBS credential flow, and
analytics fields.

### Optional: remote crash reporting

Uncaught errors are always surfaced to the user (a SnackBar with a **Details**
view over the retained error log) and logged on-device. To *also* report them
off-device, supply a crash-report URL at build time:

```sh
$ flutter build web --release --dart-define=crash_report_url=https://example.com/crash
```

Each error is then POSTed as JSON (`context`, `error`, `stack`, `time`). With no
`crash_report_url` set, nothing leaves the device.

### The computer opponent

**Play Against the Computer** on the landing page offers an eight-step
ladder: level 0 is **Harry Heuristic** (the offline pubeval evaluator), and
levels 1–7 are **Gary Gammon** — the gnubg-service's calibrated leveled
opponent (novice → world-class), consumed through the `gnubg_service`
package's attested session-token flow. Gary needs a web build configured with a publishable key and a Turnstile
sitekey. `build-web.sh` supplies playfibs.com's by default (both are public by
design: the key is origin-locked and only mints tokens behind a Turnstile
challenge). Override them — or point at a local engine — with env vars:

```sh
$ GNUBG_SERVICE_URL=http://localhost:8080 \
  GNUBG_PUBLISHABLE_KEY=bg_pk_... \
  GNUBG_TURNSTILE_SITEKEY=0x... \
  ./build-web.sh
```

Without a key (or on non-web platforms, where the browser-origin token mint
cannot run), levels 1–7 still show in the picker but are grayed out; only
Harry is playable.

Two service-side facts constrain testing: the publishable key's
`allowed_origins` must list the page's exact origin, and the Turnstile widget's
domains must list its hostname (`playfibs.com`, `www.playfibs.com`, and
`localhost` are configured). Cloudflare's Turnstile deliberately refuses
automated browsers, so **browser e2e against the hosted service cannot get past
the challenge** — automated end-to-end runs point at a local engine with
Cloudflare's always-pass test keys:

```sh
$ docker run -d --name fibscli-gnubg -p 8081:8080 \
    -e GNUBG_AUTH='[{"account_id":"fibscli","keys":[{"key":"bg_pk_fibscli_localhost","app_id":"fibscli","allowed_origins":["http://localhost:9090"],"quota":1000000,"rate_limit_per_min":0}]}]' \
    -e TOKEN_SIGNING_KEY=fibscli-local-secret \
    -e TURNSTILE_SECRET=1x0000000000000000000000000000000AA \
    gnubg-service:dev
$ GNUBG_SERVICE_URL=http://localhost:8081 \
  GNUBG_PUBLISHABLE_KEY=bg_pk_fibscli_localhost \
  GNUBG_TURNSTILE_SITEKEY=1x00000000000000000000BB \
  ./build-web.sh   # then serve build/web on port 9090
```
