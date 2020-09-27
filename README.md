# fibscli
WIP: A FIBS client written in Flutter.

# status
I'm working on the adaptable UI now, both for form factor and for input, i.e. a mouse or a finger will do.

Also I'm working on the UI gestures themselves, e.g. selection showing legal moves, moving your pieces, etc.

The goal is to host it on the desktop and mobile web and make it work against the FIBS server on fibs.com. I've got a lot of the networking/websocket proxy code already written in my FIBS.NET repo.

# screenshot
![screenshot](readme/screenshot.png)

# TODO
- mark dice as used as you use them
- show the "hit" pieces on the bar
- allow moves from the bar
- calculate legal moves from the bar
- trim legal moves when pieces are on the bar
- allow moves to bear off
- undo during a turn before it's committed
- show board in reverse
- hook up with fibs.com telnet server
- ...
- profit!
