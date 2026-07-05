part of 'cookie_monster.dart';

// ignore_for_file: public_member_api_docs

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
  _CookieDough(
    cookie: FibsCookie.FIBS_Turn,
    re: RegExp(r'^turn: ?(?<name>[a-zA-Z_<>]+)\.?'),
  ),
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
    re: RegExp(
      r'^ \*(?<player1>[a-zA-Z_<>]+) +(?<score1>[0-9]+) +(?<score2>[0-9]+) +- +(?<something>.*)',
    ),
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
