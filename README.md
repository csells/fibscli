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
