# fibscli
An eventual [FIBS](http://fibs.com) client written in Flutter and hosted on the web.

# status
Currently, the app works as a stand-alone backgammon game w/o connecting to fibs.net.

# screenshot
![screenshot](readme/screenshot.png)

You can try it live here: https://playfibs-f3c5b.web.app/#/

It works on desktop and mobile form factors.

The goal is to host it on the web and make it work against the FIBS server on fibs.com. I've got a lot of the networking/websocket proxy code already written in my fibscli_lib repo.

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
