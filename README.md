# fibscli
WIP: A FIBS client written in Flutter.

# status
I'm working on the adaptable UI now, both for form factor and for input, i.e. a mouse or a finger will do.

Also I'm working on the UI gestures themselves, e.g. selection showing legal moves, moving your pieces, etc.

The goal is to host it on the desktop and mobile web and make it work against the FIBS server on fibs.com. I've got a lot of the networking/websocket proxy code already written in my FIBS.NET repo.

# screenshot
![screenshot](readme/screenshot.png)

# TODO
- undo during a turn before it's confirmed
- show pip count
- animation of moves
- first move (different colored dice)
- implement the forced moves rule (instead of just removing moves that aren't available as you go)
- allow moves from the bar
- allow moves to bear off
- hook up with fibs.com telnet server
- ...
- profit!
