part of 'cookie_monster.dart';

// ignore_for_file: public_member_api_docs

// The CLIP/FIBS message pattern tables: each _CookieDough maps a regex to
// the cookie it produces. Ordering matters -- earlier patterns win.

// Initialize stuff, ready to start pumping out cookies by the thousands.
// Note that the order of items in this function is important, in some cases
// messages are very similar and are differentiated by depending on the
// order the batch is processed.

final _catchAllIntoMessageRegex = RegExp('(?<message>.*)');

// for RUN_STATE
final _alphaBatch = [
  _CookieDough(
    cookie: FibsCookie.FIBS_Board,
    re: RegExp(
      r'^board:(?<player1>[^:]+):(?<player2>[^:]+):(?<matchLength>\d+):(?<player1Score>\d+):(?<player2Score>\d+):(?<board>([-0-9]+:){25}\d+):(?<turnColor>-1|0|1):(?<player1Dice>\d:\d):(?<player2Dice>\d:\d):(?<doublingCube>\d+):(?<player1MayDouble>[0-1]):(?<player2MayDouble>[0-1]):(?<wasDoubled>[0-1]):(?<player1Color>-?1):(?<direction>-?1):\d+:\d+:(?<player1Home>\d+):(?<player2Home>\d+):(?<player1Bar>\d+):(?<player2Bar>\d+):(?<canMove>[0-4]):\d+:\d+:(?<redoubles>\d+)$',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouRoll,
    re: RegExp('^You roll (?<die1>[1-6]) and (?<die2>[1-6])'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerRolls,
    re: RegExp(
      '^(?<opponent>[a-zA-Z_<>]+) rolls (?<die1>[1-6]) and (?<die2>[1-6])',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RollOrDouble,
    re: RegExp(r"^It's your turn to roll or double\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RollOrDouble,
    re: RegExp(r"^It's your turn\. Please roll or double"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_AcceptRejectDouble,
    re: RegExp(
      r"^(?<opponent>[a-zA-Z_<>]+) doubles\. Type 'accept' or 'reject'\.",
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Doubles,
    re: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) doubles\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
    re: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) accepts the double\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PleaseMove,
    re: RegExp(r'^Please move (?<pieces>[1-4]) pieces?\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerMoves,
    re: RegExp('^(?<player>[a-zA-Z_<>]+) moves (?<moves>[0-9- ]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerCantMove,
    re: RegExp("^(?<player>[a-zA-Z_<>]+) can't move"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_BearingOff,
    re: RegExp('^Bearing off: (?<bearing>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouReject,
    re: RegExp(r'^You reject\. The game continues\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouStopWatching,
    re: RegExp(
      r"(?<name>[a-zA-Z_<>]+) logs out\. You're not watching anymore\.",
    ),
  ), // overloaded	//PLAYER logs out. You're not watching anymore.
  _CookieDough(
    cookie: FibsCookie.FIBS_OpponentLogsOut,
    re: RegExp(r'^(?<opponent>[a-zA-Z_<>]+) logs out\. The game was saved'),
  ), // PLAYER logs out. The game was saved.
  _CookieDough(
    cookie: FibsCookie.FIBS_OpponentLogsOut,
    re: RegExp(
      r'^(?<opponent>[a-zA-Z_<>]+) drops connection\. The game was saved',
    ),
  ), // PLAYER drops connection. The game was saved.
  _CookieDough(
    cookie: FibsCookie.FIBS_OnlyPossibleMove,
    re: RegExp('^The only possible move is (?<move>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_FirstRoll,
    re: RegExp(
      '(?<opponent>[a-zA-Z_<>]+) rolled (?<opponentDie>[1-6]).+rolled '
      '(?<yourDie>[1-6])',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MakesFirstMove,
    re: RegExp(r'(?<opponent>[a-zA-Z_<>]+) makes the first move\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouDouble,
    re: RegExp(
      r'^You double\. Please wait for (?<opponent>[a-zA-Z_<>]+) to accept or reject',
    ),
  ), // You double. Please wait for PLAYER to accept or reject.
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerWantsToResign,
    re: RegExp(
      r"^(?<opponent>[a-zA-Z_<>]+) wants to resign\. You will win (?<points>[0-9]+) points?\. Type 'accept' or 'reject'\.",
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WatchResign,
    re: RegExp(
      r'^(?<player1>[a-zA-Z_<>]+) wants to resign\. '
      '(?<player2>[a-zA-Z_<>]+) will win (?<points>[0-9]+) points',
    ),
  ), // PLAYER wants to resign. PLAYER2 will win 2 points.  (ORDER MATTERS)
  _CookieDough(
    cookie: FibsCookie.FIBS_YouResign,
    re: RegExp(
      '^You want to resign. (?<opponent>[a-zA-Z_<>]+) will win '
      '(?<points>[0-9]+)',
    ),
  ), // You want to resign. PLAYER will win 1 .
  _CookieDough(
    cookie: FibsCookie.FIBS_ResumeMatchAck5,
    re: RegExp(
      r'^You are now playing with (?<opponent>[a-zA-Z_<>]+)\. Your running match was loaded',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_JoinNextGame,
    re: RegExp(
      r"^Type 'join' if you want to play the next game, type 'leave' if you don't\.",
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NewMatchRequest,
    re: RegExp(
      r'^(?<name>[a-zA-Z_<>]+) wants to play a (?<points>[0-9]+) point match with you\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WARNINGSavedMatch,
    re: RegExp("^WARNING: Don't accept if you want to continue"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ResignRefused,
    re: RegExp(r'^(?<opponent>[a-zA-Z_<>]+) rejects\. The game continues\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MatchLength,
    re: RegExp('^match length: (?<length>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_TypeJoin,
    re: RegExp(r"^Type 'join (?<opponent>[a-zA-Z_<>]+)' to accept\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouAreWatching,
    re: RegExp("^You're now watching (?<name>[a-zA-Z_<>]+)"),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouStopWatching,
    re: RegExp('^You stop watching (?<name>[a-zA-Z_<>]+)'),
  ), // overloaded
  _CookieDough(
    cookie: FibsCookie.FIBS_NotDoingAnything,
    re: RegExp(r'^(?<name>[a-zA-Z_<>]+) is not doing anything interesting\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerStartsWatching,
    re: RegExp(
      '(?<player1>[a-zA-Z_<>]+) starts watching (?<player2>[a-zA-Z_<>]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerStartsWatching,
    re: RegExp('(?<name>[a-zA-Z_<>]+) is watching you'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerStopsWatching,
    re: RegExp('(?<name>[a-zA-Z_<>]+) stops watching (?<player>[a-zA-Z_<>]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerIsWatching,
    re: RegExp('(?<name>[a-zA-Z_<>]+) is watching '),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerLeftGame,
    re: RegExp(
      '(?<player1>[a-zA-Z_<>]+) has left the game with '
      '(?<player2>[a-zA-Z_<>]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ResignWins,
    re: RegExp(
      r'^(?<player1>[a-zA-Z_<>]+) gives up\. (?<player2>[a-zA-Z_<>]+) wins (?<points>[0-9]+) points?',
    ),
  ), // PLAYER1 gives up. PLAYER2 wins 1 point.
  _CookieDough(
    cookie: FibsCookie.FIBS_ResignYouWin,
    re: RegExp(
      r'^(?<opponent>[a-zA-Z_<>]+) gives up\. You win (?<points>[0-9]+) points',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouAcceptAndWin,
    re: RegExp('^You accept and win (?<something>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_AcceptWins,
    re: RegExp(
      '^(?<opponent>[a-zA-Z_<>]+) accepts and wins (?<points>[0-9]+) '
      'point',
    ),
  ), // PLAYER accepts and wins N points.
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayersStartingMatch,
    re: RegExp(
      '^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start a '
      '(?<points>[0-9]+) point match',
    ),
  ), // PLAYER and PLAYER start a <n> point match.
  _CookieDough(
    cookie: FibsCookie.FIBS_StartingNewGame,
    re: RegExp('^Starting a  game with (?<opponent>[a-zA-Z_<>]+)'),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_YouGiveUp, re: RegExp('^You give up')),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouWinMatch,
    re: RegExp(
      '^You win the (?<points>[0-9]+) point match '
      '(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerWinsMatch,
    re: RegExp(
      '^(?<opponent>[a-zA-Z_<>]+) wins the (?<points>[0-9]+) point match '
      '(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)',
    ),
  ), //PLAYER wins the 3 point match 3-0 .
  _CookieDough(
    cookie: FibsCookie.FIBS_ResumingUnlimitedMatch,
    re: RegExp(
      r'^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their unlimited match\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ResumingLimitedMatch,
    re: RegExp(
      r'^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their (?<points>[0-9]+)-point match\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MatchResult,
    re: RegExp(
      '^(?<winner>[a-zA-Z_<>]+) wins a (?<points>[0-9]+) point match '
      'against (?<loser>[a-zA-Z_<>]+) '
      '+(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)',
    ),
  ), //PLAYER wins a 9 point match against PLAYER  11-6 .
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerWantsToResign,
    re: RegExp(r'^(?<name>[a-zA-Z_<>]+) wants to resign\.'),
  ), //  Same as a longline in an actual game  This is just for watching.
  _CookieDough(
    cookie: FibsCookie.FIBS_BAD_AcceptDouble,
    re: RegExp(
      r'^(?<name>[a-zA-Z_<>]+) accepts? the double\. The cube shows (?<cube>[0-9]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouAcceptDouble,
    re: RegExp(r'^You accept the double\. The cube shows (?<cube>[0-9]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
    re: RegExp(
      r'(?<name>^[a-zA-Z_<>]+) accepts the double\. The cube shows (?<cube>[0-9]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
    re: RegExp('^(?<name>[a-zA-Z_<>]+) accepts the double'),
  ), // while watching
  _CookieDough(
    cookie: FibsCookie.FIBS_ResumeMatchRequest,
    re: RegExp('^(?<name>[a-zA-Z_<>]+) wants to resume a saved match with you'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ResumeMatchAck0,
    re: RegExp(
      r'^(?<opponent>[a-zA-Z_<>]+) has joined you\. Your running match was loaded',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_YouWinGame,
    re: RegExp('^You win the game and get (?<points>[0-9]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_UnlimitedInvite,
    re: RegExp(
      '^(?<name>[a-zA-Z_<>]+) wants to play an unlimted match with you',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerWinsGame,
    re: RegExp(
      '^(?<opponent>[a-zA-Z_<>]+) wins the game and gets (?<points>[0-9]+) '
      'points?. Sorry',
    ),
  ),
  // CookieDough (cookie: FibsCookie.FIBS_PlayerWinsGame, regex: RegExp(r"^[a-zA-Z_<>]+ wins the game and gets [0-9] points?."),), // (when watching)
  _CookieDough(
    cookie: FibsCookie.FIBS_WatchGameWins,
    re: RegExp(
      '^(?<name>[a-zA-Z_<>]+) wins the game and gets '
      '(?<points>[0-9]+) points',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayersStartingUnlimitedMatch,
    re: RegExp(
      '^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start an '
      'unlimited match',
    ),
  ), // PLAYER_A and PLAYER_B start an unlimited match.
  _CookieDough(
    cookie: FibsCookie.FIBS_ReportLimitedMatch,
    re: RegExp(
      '^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) '
      '(?<points>[0-9]+) point match (?<score1>[0-9]+)-(?<score2>[0-9]+)',
    ),
  ), // PLAYER_A        -       PLAYER_B (5 point match 2-2)
  _CookieDough(
    cookie: FibsCookie.FIBS_ReportUnlimitedMatch,
    re: RegExp(
      r'^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) \(unlimited (?<something>.*)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesStart,
    re: RegExp(
      '^(?<playerX>[a-zA-Z_<>]+) is X - (?<playerO>[a-zA-Z_<>]+) is O',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesRoll,
    re: RegExp(r'^[XO]: \([1-6]'),
  ), // ORDER MATTERS HERE
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesWins,
    re: RegExp('^[XO]: wins'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesDoubles,
    re: RegExp('^[XO]: doubles'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesAccepts,
    re: RegExp('^[XO]: accepts'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesRejects,
    re: RegExp('^[XO]: rejects'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ShowMovesOther,
    re: RegExp('^[XO]:'),
  ), // AND HERE
  _CookieDough(
    cookie: FibsCookie.FIBS_ScoreUpdate,
    re: RegExp('^score in (?<points>[0-9]+) point match:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MatchStart,
    re: RegExp(
      r'^Score is (?<score1>[0-9]+)-(?<score2>[0-9]+) in a (?<points>[0-9]+) point match\.',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsHeader,
    re: RegExp('^Settings of variables:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp(
      '^(?<name>allowpip|autoboard|autodouble|automove|bell|crawford|double'
      '|moreboards|moves|greedy|notify|ratings|ready|report|silent|telnet|'
      'wrap) +(?<value>YES|NO)',
    ),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_Turn, re: RegExp('^turn:')),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>boardstyle): +(?<value>[1-3])'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(r"^Value of '(?<name>boardstyle)' set to (?<value>[1-3])\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>linelength): +(?<value>[0-9]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(r"^Value of '(?<name>linelength)' set to (?<value>[0-9]+)\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>pagelength): +(?<value>[0-9]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(r"^Value of '(?<name>pagelength)' set to (?<value>[0-9]+)\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>redoubles): +(?<value>none|unlimited|[0-9]+)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(
      r"^Value of '(?<name>redoubles)' set to '?(?<value>none|unlimited|[0-9]+)'?\.",
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>sortwho): +(?<value>login|name|rating|rrating)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(
      "^Value of '(?<name>sortwho)' set to "
      '(?<value>login|name|rating|rrating)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsValue,
    re: RegExp('^(?<name>timezone): +(?<value>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsChange,
    re: RegExp(r"^Value of '(?<name>timezone)' set to (?<value>.*)\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_CantMove,
    re: RegExp("^(?<name>[a-zA-Z_<>]+) can't move"),
  ), // PLAYER can't move || You can't move
  _CookieDough(
    cookie: FibsCookie.FIBS_ListOfGames,
    re: RegExp('^List of games:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerInfoStart,
    re: RegExp('^Information about'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_EmailAddress,
    re: RegExp('^  Email address:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoEmail,
    re: RegExp('^  No email address'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WavesAgain,
    re: RegExp('^(?<name>[a-zA-Z_<>]+) waves goodbye again'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Waves,
    re: RegExp('^(?<name>[a-zA-Z_<>]+) waves goodbye'),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_Waves, re: RegExp('^You wave goodbye')),
  _CookieDough(
    cookie: FibsCookie.FIBS_WavesAgain,
    re: RegExp('^You wave goodbye again and log out'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoSavedGames,
    re: RegExp('^no saved games'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SavedMatch,
    re: RegExp(
      '^  (?<player1>[a-zA-Z_<>]+) +(?<score1>[0-9]+) +(?<score2>[0-9]+) '
      '+- +(?<something>.*)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SavedMatchPlaying,
    re: RegExp(r'^ \*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +'),
  ),
  // NOTE: for FIBS_SavedMatchReady, see the Stars message, because it will
  // appear to be one of those (has asterisk at index 0).
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerIsWaitingForYou,
    re: RegExp(r'^[a-zA-Z_<>]+ is waiting for you to log in\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_IsAway,
    re: RegExp('^[a-zA-Z_<>]+ is away: '),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Junk,
    re: RegExp('^Closed old connection with user'),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_Done, re: RegExp(r'^Done\.')),
  _CookieDough(
    cookie: FibsCookie.FIBS_YourTurnToMove,
    re: RegExp(r"^It's your turn to move\."),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SavedMatchesHeader,
    re: RegExp(
      r'^  opponent          matchlength   score \(your points first\)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_MessagesForYou,
    re: RegExp('^There are messages for you:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_DoublingCubeNow,
    re: RegExp('^The number on the doubling cube is now [0-9]+'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_FailedLogin,
    re: RegExp('^> [0-9]+'),
  ), // bogus CLIP messages sent after a failed login
  _CookieDough(
    cookie: FibsCookie.FIBS_Average,
    re: RegExp('^Time (UTC)  average min max'),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_DiceTest, re: RegExp('^[nST]: ')),
  _CookieDough(
    cookie: FibsCookie.FIBS_LastLogout,
    re: RegExp('^  Last logout:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcStart,
    re: RegExp('^rating calculation:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('^Probability that underdog wins:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('is 1-Pu if underdog wins'),
  ), // P=0.505861 is 1-Pu if underdog wins and Pu if favorite wins
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('^Experience: '),
  ), // Experience: fergy 500 - jfk 5832
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp(r'^K=max\(1'),
  ), // K=max(1 ,		-Experience/100+5) for fergy: 1.000000
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('^rating difference'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('^change for'),
  ), // change for fergy: 4*K*sqrt(N)*P=2.023443
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingCalcInfo,
    re: RegExp('^match length  '),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_WatchingHeader,
    re: RegExp('^Watching players:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SettingsHeader,
    re: RegExp('^The current settings are:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_AwayListHeader,
    re: RegExp('^The following users are away:'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingExperience,
    re: RegExp(r'^  Rating: +[0-9]+\.'),
  ), // Rating: 1693.11 Experience: 5781
  _CookieDough(
    cookie: FibsCookie.FIBS_NotLoggedIn,
    re: RegExp(r'^  Not logged in right now\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_IsPlayingWith,
    re: RegExp('is playing with'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_SavedScoreHeader,
    re: RegExp('^opponent +matchlength'),
  ), //	opponent          matchlength   score (your points first)
  _CookieDough(
    cookie: FibsCookie.FIBS_StillLoggedIn,
    re: RegExp(r'^  Still logged in\.'),
  ), //  Still logged in. 2:12 minutes idle.
  _CookieDough(
    cookie: FibsCookie.FIBS_NoOneIsAway,
    re: RegExp(r'^None of the users is away\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_PlayerListHeader,
    re: RegExp('^No  S  username        rating  exp login    idle  from'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_RatingsHeader,
    re: RegExp('^ rank name            rating    Experience'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_ClearScreen,
    re: RegExp(r'^.\[, },H.\[2J'),
  ), // ANSI clear screen sequence
  _CookieDough(
    cookie: FibsCookie.FIBS_Timeout,
    re: RegExp(r'^Connection timed out\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Goodbye,
    re: RegExp(r'(?<message>           Goodbye\.)'),
  ),
  _CookieDough(cookie: FibsCookie.FIBS_LastLogin, re: RegExp('^  Last login:')),
  _CookieDough(
    cookie: FibsCookie.FIBS_NoInfo,
    re: RegExp('^No information found on user'),
  ),
  _setting('away', 'YES', r"^You're away\. Please type 'back'"),
  _setting('away', 'NO', r'^Welcome back\.'),
];

//--- Numeric messages ---------------------------------------------------
final _numericBatch = [
  _CookieDough(
    cookie: FibsCookie.CLIP_WHO_INFO,
    re: RegExp(
      r'^5 (?<name>[^ ]+) (?<opponent>[^ ]+) (?<watching>[^ ]+) (?<ready>[01]) (?<away>[01]) (?<rating>[0-9]+\.[0-9]+) (?<experience>[0-9]+) (?<idle>[0-9]+) (?<login>[0-9]+) (?<hostName>[^ ]+) (?<client>[^ ]+) (?<email>[^ ]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Average,
    re: RegExp('^[0-9][0-9]:[0-9][0-9]-'),
  ), // output of average command
  _CookieDough(
    cookie: FibsCookie.FIBS_DiceTest,
    re: RegExp('^[1-6]-1 [0-9]'),
  ), // output of dicetest command
  _CookieDough(cookie: FibsCookie.FIBS_DiceTest, re: RegExp('^[1-6]: [0-9]')),
  _CookieDough(
    cookie: FibsCookie.FIBS_Stat,
    re: RegExp('^[0-9]+ bytes'),
  ), // output from stat command
  _CookieDough(cookie: FibsCookie.FIBS_Stat, re: RegExp('^[0-9]+ accounts')),
  _CookieDough(
    cookie: FibsCookie.FIBS_Stat,
    re: RegExp('^[0-9]+ ratings saved. reset log'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Stat,
    re: RegExp('^[0-9]+ registered users.'),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Stat,
    re: RegExp(r'^[0-9]+\([0-9]+\) saved games check by cron'),
  ),
  _CookieDough(cookie: FibsCookie.CLIP_WHO_END, re: RegExp(r'^6$')),
  _CookieDough(
    cookie: FibsCookie.CLIP_SHOUTS,
    re: RegExp('^13 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_SAYS,
    re: RegExp('^12 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_WHISPERS,
    re: RegExp('^14 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_KIBITZES,
    re: RegExp('^15 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_YOU_SAY,
    re: RegExp('^16 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_YOU_SHOUT,
    re: RegExp('^17 (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_YOU_WHISPER,
    re: RegExp('^18 (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_YOU_KIBITZ,
    re: RegExp('^19 (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_LOGIN,
    re: RegExp('^7 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_LOGOUT,
    re: RegExp('^8 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_MESSAGE,
    re: RegExp('^9 (?<from>[a-zA-Z_<>]+) (?<time>[0-9]+) (?<message>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_MESSAGE_DELIVERED,
    re: RegExp(r'^10 (?<name>[a-zA-Z_<>]+)$'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_MESSAGE_SAVED,
    re: RegExp(r'^11 (?<name>[a-zA-Z_<>]+)$'),
  ),
];

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
      r'^\*\* Player [a-zA-Z_<>]+ has left the game. The game was saved\.',
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
    re: RegExp(r'^\*\*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +[0-9]+'),
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

// for LOGIN_STATE
final _loginBatch = [
  _CookieDough(cookie: FibsCookie.FIBS_LoginPrompt, re: RegExp('^login:')),
  _CookieDough(
    cookie: FibsCookie.FIBS_WARNINGAlreadyLoggedIn,
    re: RegExp(r'^\*\* Warning: You are already logged in\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_WELCOME,
    re: RegExp('^1 (?<name>[a-zA-Z_<>]+) (?<lastLogin>[0-9]+) (?<lastHost>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_OWN_INFO,
    re: RegExp(
      r'^2 (?<name>[a-zA-Z_<>]+) (?<allowpip>[01]) (?<autoboard>[01]) (?<autodouble>[01]) (?<automove>[01]) (?<away>[01]) (?<bell>[01]) (?<crawford>[01]) (?<double>[01]) (?<experience>[0-9]+) (?<greedy>[01]) (?<moreboards>[01]) (?<moves>[01]) (?<notify>[01]) (?<rating>[0-9]+\.[0-9]+) (?<ratings>[01]) (?<ready>[01]) (?<redoubles>[0-9a-zA-Z]+) (?<report>[01]) (?<silent>[01]) (?<timezone>.*)',
    ),
  ),
  _CookieDough(cookie: FibsCookie.CLIP_MOTD_BEGIN, re: RegExp(r'^3$')),
  _CookieDough(
    cookie: FibsCookie.FIBS_FailedLogin,
    re: RegExp('^> [0-9]+'),
  ), // bogus CLIP messages sent after a failed login
  _CookieDough(
    cookie: FibsCookie.FIBS_FailedLogin,
    re: RegExp('^Login incorrect'),
  ), // JIBS
  _CookieDough(
    cookie: FibsCookie.FIBS_PreLogin,
    re: _catchAllIntoMessageRegex,
  ), // catch all
];

// Only interested in one message here, but we still use a message list for
// simplicity and consistency. for MOTD_STATE
final _motdBatch = [
  _CookieDough(cookie: FibsCookie.CLIP_MOTD_END, re: RegExp(r'^4$')),
  _CookieDough(
    cookie: FibsCookie.FIBS_MOTD,
    re: _catchAllIntoMessageRegex,
  ), // catch all
];
