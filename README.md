# fibscli
WIP: A FIBS client written in Flutter.

# status
I'm working on the adaptable UI now, both for form factor and for input, i.e. a mouse or a finger will do.

Also I'm working on the UI gestures themselves, e.g. selection showing legal moves, moving your pieces, etc.

The goal is to host it on the desktop and mobile web and make it work against the FIBS server on fibs.com. I've got a lot of the networking/websocket proxy code already written in my FIBS.NET repo.

# screenshot
![screenshot](readme/screenshot.png)

# TODO
- allow moves to bear off
- detect end game
- fix multi-piece off of home bug
- first move (different colored dice)
- test the GammonState + GammonRules
- animation of moves (including hops)
- animated board rotation
- implement the forced moves rule (instead of just removing moves that aren't available as you go)
- hook up with fibs.com telnet server
- ...
- profit!

# Legal turns algorithm
find composits of all pieces on all pips + bar (up to number of dice) for the player, e.g. white: [1, 1, 12, 12, 12, 12, 12, ...]
  e.g. piece composit == [1, 1] (no doubles),  [1, 1, 12, 12] (doubles)
find composits of all dice
  e.g. dice composit == [4, 5] (no doubles), [4, 4, 4, 4] (doubles)
zip each piece composit with composit of all dice
  e.g. [1-4, 1-5] (no doubles), [1-4, 1-4, 12-4, 12-4] (doubles)
