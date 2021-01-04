# fibscli
WIP: A FIBS client written in Flutter.

# status
I'm working on the adaptable UI now, both for form factor and for input, i.e. a mouse or a finger will do.

Also I'm working on the UI gestures themselves, e.g. selection showing legal moves, moving your pieces, etc.

The goal is to host it on the desktop and mobile web and make it work against the FIBS server on fibs.com. I've got a lot of the networking/websocket proxy code already written in my FIBS.NET repo.

# screenshot
![screenshot](readme/screenshot.png)

# usage
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

# FIBS TODO
- live chat
- watch backgammon
- play backgammon

# UI TODO
- prefer moves w/ hits when picking from multiple moves
- remove dups from generated legal moves for doubles (test: open + double 4s)
- shouldn't allow any other moves while dice are on the bar
- move a hit piece *after* it's been hit
- draw moving pieces on top of other pieces
- don't show the label while it's moving
- detect end game
- first move (different colored dice)
- test the GammonState + GammonRules
- implement the forced moves rule (instead of just removing moves that aren't available as you go)

# Legal turns algorithm
find composits of all pieces on all pips + bar (up to number of dice) for the player, e.g. white: [1, 1, 12, 12, 12, 12, 12, ...]
  e.g. piece composit == [1, 1] (no doubles),  [1, 1, 12, 12] (doubles)
find composits of all dice
  e.g. dice composit == [4, 5] (no doubles), [4, 4, 4, 4] (doubles)
zip each piece composit with composit of all dice
  e.g. [1-4, 1-5] (no doubles), [1-4, 1-4, 12-4, 12-4] (doubles)
the rest TBD...