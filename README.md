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
`www.playfibs.com` custom domains. Deploy the site with:

```sh
$ ./build-web.sh
$ cd packages/playfibs_site
$ npm ci
$ npm run check && npm test
$ npx wrangler deploy
```

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
package's attested session-token flow. Gary needs a web build configured
with a publishable key and a Turnstile sitekey:

```sh
$ flutter build web --release \
    --dart-define=gnubg_publishable_key=bg_pk_... \
    --dart-define=gnubg_turnstile_sitekey=0x... \
    --dart-define=gnubg_service_url=...   # optional; defaults to the hosted service
```

Without a key (or on non-web platforms, where the browser-origin token mint
cannot run), levels 1–7 still show in the picker but are grayed out; only
Harry is playable.
