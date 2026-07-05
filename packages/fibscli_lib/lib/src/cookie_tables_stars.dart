part of 'cookie_monster.dart';

// ignore_for_file: public_member_api_docs

//--- '**' messages ------------------------------------------------------
final _starsBatch = [
  _CookieDough(cookie: FibsCookie.FIBS_Username, re: RegExp(r'^\*\* User')),
  _CookieDough(
    cookie: FibsCookie.FIBS_Junk,
    re: RegExp(r'^\*\* You tell '),
  ), // "** You tell PLAYER: xxxxx"
  _CookieDough(cookie: FibsCookie.FIBS_YouGag, re: RegExp(r'^\*\* You gag')),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouUngag,
    re: RegExp(r'^\*\* You ungag'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouBlind,
    re: RegExp(r'^\*\* You blind'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouUnblind,
    re: RegExp(r'^\*\* You unblind'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_UseToggleReady,
    re: RegExp(r"^\*\* Use 'toggle ready' first"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NewMatchAck9,
    re: RegExp(r'^\*\* You are now playing an unlimited match with '),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NewMatchAck10,
    re: RegExp(r'^\*\* You are now playing a [0-9]+ point match with '),
  ), // ** You are now playing a 5 point match with PLAYER
  _CookieDough(
    cookie: FibsCookie.FIBS_NewMatchAck2,
    re: RegExp(
      r'^\*\* Player (?<name>[a-zA-Z_<>]+) has joined you for a (?<points>[0-9]+) point match',
    ),
  ), // ** Player PLAYER has joined you for a 2 point match.
  _CookieDough(
    cookie: FibsCookie.FIBS_YouTerminated,
    re: RegExp(r'^\*\* You terminated the game'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_OpponentLeftGame,
    re: RegExp(
      r'^\*\* Player (?<opponent>[a-zA-Z_<>]+) has left the game\. The game was saved\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerLeftGame,
    re: RegExp(r'has left the game\.'),
  ), // overloaded
  _CookieDough(
    cookie: FibsCookie.FIBS_YouInvited,
    re: RegExp(r'^\*\* You invited'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YourLastLogin,
    re: RegExp(r'^\*\* Last login:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoOne,
    re: RegExp(r'^\*\* There is no one called (?<name>[a-zA-Z_<>]+)'),
  ),
  _setting(
    'allowpip',
    'YES',
    r"^\*\* You allow the use the server's 'pip' command\.",
  ),
  _setting(
    'allowpip',
    'NO',
    r"^\*\* You don't allow the use of the server's 'pip' command\.",
  ),
  _setting('autoboard', 'YES', r'^\*\* The board will be refreshed'),
  _setting('autoboard', 'NO', r"^\*\* The board won't be refreshed"),
  _setting('autodouble', 'YES', r'^\*\* You agree that doublets'),
  _setting('autodouble', 'NO', r"^\*\* You don't agree that doublets"),
  _setting('automove', 'YES', r'^\*\* Forced moves will'),
  _setting('automove', 'NO', r"^\*\* Forced moves won't"),
  _setting('bell', 'YES', r'^\*\* Your terminal will ring'),
  _setting('bell', 'NO', r"^\*\* Your terminal won't ring"),
  _setting(
    'crawford',
    'YES',
    r'^\*\* You insist on playing with the Crawford rule\.',
  ),
  _setting(
    'crawford',
    'NO',
    r'^\*\* You would like to play without using the Crawford rule\.',
  ),
  _setting('double', 'YES', r'^\*\* You will be asked if you want to double\.'),
  _setting('double', 'NO', r"^\*\* You won't be asked if you want to double\."),
  _setting('greedy', 'YES', r'^\*\* Will use automatic greedy bearoffs\.'),
  _setting('greedy', 'NO', r"^\*\* Won't use automatic greedy bearoffs\."),
  _setting('moreboards', 'YES', r'^\*\* Will send rawboards after rolling\.'),
  _setting('moreboards', 'NO', r"^\*\* Won't send rawboards after rolling\."),
  _setting('moves', 'YES', r'^\*\* You want a list of moves after this game\.'),
  _setting(
    'moves',
    'NO',
    r"^\*\* You won't see a list of moves after this game\.",
  ),
  _setting('notify', 'YES', r"^\*\* You'll be notified"),
  _setting('notify', 'NO', r"^\*\* You won't be notified"),
  _setting(
    'ratings',
    'YES',
    r"^\*\* You'll see how the rating changes are calculated\.",
  ),
  _setting(
    'ratings',
    'NO',
    r"^\*\* You won't see how the rating changes are calculated\.",
  ),
  _setting(
    'ready',
    'YES',
    r"^\*\* You're now ready to invite or join someone\.",
  ),
  _setting('ready', 'NO', r"^\*\* You're now refusing to play with someone\."),
  _setting('report', 'YES', r'^\*\* You will be informed'),
  _setting('report', 'NO', r"^\*\* You won't be informed"),
  _setting('silent', 'YES', r'^\*\* You will hear what other players shout\.'),
  _setting('silent', 'NO', r"^\*\* You won't hear what other players shout\."),
  _setting('telnet', 'YES', r'^\*\* You use telnet'),
  _setting('telnet', 'NO', r'^\*\* You use a client program'),
  _setting('wrap', 'YES', r'^\*\* The server will wrap'),
  _setting('wrap', 'NO', r'^\*\* Your terminal knows how to wrap'),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerRefusingGames,
    re: RegExp(r'^\*\* [a-zA-Z_<>]+ is refusing games\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NotWatching,
    re: RegExp(r"^\*\* You're not watching\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NotWatchingPlaying,
    re: RegExp(r"^\*\* You're not watching or playing\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NotPlaying,
    re: RegExp(r"^\*\* You're not playing\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoUser,
    re: RegExp(r'^\*\* There is no one called '),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_AlreadyPlaying,
    re: RegExp('is already playing with'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_DidntInvite,
    re: RegExp(r"^\*\* [a-zA-Z_<>]+ didn't invite you."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_BadMove,
    re: RegExp(r"^\*\* You can't remove this piece"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantMoveFirstMove,
    re: RegExp(r"^\*\* You can't move "),
  ), // ** You can't move 3 points in your first move
  _CookieDough(
    cookie: FibsCookie.FIBS_CantShout,
    re: RegExp(r"^\*\* Please type 'toggle silent' again before you shout\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MustMove,
    re: RegExp(r'^\*\* You must give [1-4] moves'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MustComeIn,
    re: RegExp(
      r'^\*\* You have to remove pieces from the bar in your first move\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_UsersHeardYou,
    re: RegExp(r'^\*\* [0-9]+ users? heard you\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Junk,
    re: RegExp(r'^\*\* Please wait for [a-zA-Z_<>]+ to join too\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SavedMatchReady,
    re: RegExp(
      r'^\*\*(?<player1>[a-zA-Z_<>]+) +(?<score1>[0-9]+) +(?<score2>[0-9]+) +- +(?<something>[0-9]+)',
    ),
  ), // double star before a name indicates a saved game with this player
  _CookieDough(
    cookie: FibsCookie.FIBS_NotYourTurnToRoll,
    re: RegExp(r"^\*\* It's not your turn to roll the dice\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NotYourTurnToMove,
    re: RegExp(r"^\*\* It's not your turn to move\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouStopWatching,
    re: RegExp(r'^\*\* You stop watching'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_UnknownCommand,
    re: RegExp(r'^\*\* Unknown command: (?<command>.*)$'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantWatch,
    re: RegExp(r"^\*\* You can't watch another game while you're playing\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantInviteSelf,
    re: RegExp(r"^\*\* You can't invite yourself\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_DontKnowUser,
    re: RegExp(r"^\*\* Don't know user"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MessageUsage,
    re: RegExp(r'^\*\* usage: message <user> <text>'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerNotPlaying,
    re: RegExp(r'^\*\* [a-zA-Z_<>]+ is not playing\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantTalk,
    re: RegExp(r"^\*\* You can't talk if you won't listen\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WontListen,
    re: RegExp(r"^\*\* [a-zA-Z_<>]+ won't listen to you\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Why,
    re: RegExp('Why would you want to do that'),
  ), // (not sure about ** vs *** at front of line.)
  _CookieDough(
    cookie: FibsCookie.FIBS_Ratings,
    re: RegExp(r'^\* *[0-9]+ +[a-zA-Z_<>]+ +[0-9]+\.[0-9]+ +[0-9]+'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoSavedMatch,
    re: RegExp(r"^\*\* There's no saved match with "),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WARNINGSavedMatch,
    re: RegExp(r"^\*\* WARNING: Don't accept if you want to continue"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantGagYourself,
    re: RegExp(r"^\*\* You talk too much, don't you\?"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantBlindYourself,
    re: RegExp(r"^\*\* You can't read this message now, can you\?"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp(r"^\*\* You're not away\."),
    extras: {'name': 'away', 'value': 'NO'},
  ),
];
