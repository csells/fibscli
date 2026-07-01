# fibscli
An eventual [FIBS](http://fibs.com) client written in Flutter and hosted on the web.

# status
The app works both as a stand-alone backgammon game (single-player and vs. computer) **and** as a working FIBS client — login, live bot list, watch, and tap-to-move play against bots on fibs.com (over a websocat proxy, see below).

# screenshot
![screenshot](readme/screenshot.png)

You can try it live here: https://playfibs-f3c5b.web.app/#/

It works on desktop and mobile form factors.

All of the FIBS networking / websocket-proxy code now lives **in this repo** as a first-party workspace package (`packages/fibscli_lib`). This repo owns 100% of its source — there is no external upstream and nothing to sync to.

# FIBS development
fibscli uses [websocat](https://github.com/vi/websocat) to proxy from websockets to telnet.

If running JIBS locally, then configure websocat like this:

```sh
$ websocat --binary ws-l:127.0.0.1:8080 tcp:127.0.0.1:4321 --exit-on-eof -v
```

If running against fibs.com, then configure webtelnet like this:

```sh
$ websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof -v
```

Now running fibscli will use a websocket on port 8080 of the localhost to connect to either JIBS or FIBS as appropriate.

## Production build & deployment

Build the release web bundle:

```sh
$ ./build-web.sh   # flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
```

The output in `build/web` is a static bundle. To play FIBS from a deployed
build, a `websocat` proxy (above) must be reachable from wherever the app runs —
the browser can't open a raw telnet socket, so the websocket→telnet hop is
required in production too.

Point the app at a hosted proxy at build time (defaults are `localhost:8080`
over plain `ws://`). A build served from an `https://` origin must use a `wss://`
proxy:

```sh
$ flutter build web --release \
    --dart-define=fibs_proxy_host=proxy.example.com \
    --dart-define=fibs_proxy_port=443 \
    --dart-define=fibs_proxy_secure=true
```

### Optional: remote crash reporting

Uncaught errors are always surfaced to the user (a SnackBar with a **Details**
view over the retained error log) and logged on-device. To *also* report them
off-device, supply a crash-report URL at build time:

```sh
$ flutter build web --release --dart-define=crash_report_url=https://example.com/crash
```

Each error is then POSTed as JSON (`context`, `error`, `stack`, `time`). With no
`crash_report_url` set, nothing leaves the device.

### Optional: the gnubg engine

The **Play vs Computer** picker always offers the built-in pubeval engine and
the bundled Gary Gammon. To also offer the world-class **GNU Backgammon**
engine, point the build at a gnubg-service:

```sh
$ flutter build web --release \
    --dart-define=gnubg_service_url=https://gnubg.example.com \
    --dart-define=gnubg_api_key=...   # optional, sent as x-api-key
```

With no `gnubg_service_url`, the gnubg engine is simply not listed.
