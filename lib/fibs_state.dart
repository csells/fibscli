import 'dart:developer' as dev;

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';

import 'fibs_board.dart';
import 'fibs_move.dart';
import 'fibs_play.dart';
import 'fibs_transport.dart';
import 'main.dart';
import 'model.dart';
import 'tinystate.dart';

// Thrown when a play command is issued in a state FIBS isn't ready for. We
// surface these loudly rather than silently dropping the command -- a dropped
// command hides the real bug (sending at the wrong time) and is impossible to
// diagnose, whereas an exception points straight at the offending caller.
class FibsStateError extends StateError {
  FibsStateError(super.message);
}

class FibsMessage {
  FibsMessage(this.cookie, this.from, this.message);
  final FibsCookie cookie;
  final String from;
  final String message;

  @override
  String toString() => '$from $_cookieName "$message"';

  String get _cookieName {
    switch (cookie) {
      case FibsCookie.CLIP_KIBITZES:
        return 'kibitzes';
      case FibsCookie.CLIP_SAYS:
        return 'says';
      case FibsCookie.CLIP_SHOUTS:
        return 'shouts';
      case FibsCookie.CLIP_WHISPERS:
        return 'whispers';
      // ignore: no_default_cases
      default:
        throw Exception('unreachable');
    }
  }
}

class FibsState extends ChangeNotifier {
  // The proxy host/port the websocat bridge listens on (see README). Defaults
  // to the local bridge; overridable so tooling can target 127.0.0.1 directly.
  FibsState({String proxy = 'localhost', int port = 8080})
      : _conn = FibsConnectionTransport(FibsConnection(proxy, port));

  // Inject a transport (e.g. a fake) to drive the state without a live server.
  FibsState.withTransport(this._conn);

  final whoInfos = NotifierList<WhoInfo>();
  final messages = NotifierList<FibsMessage>();
  final FibsTransport _conn;
  String? _user;

  // the most recent board state of the game being watched/played, mapped into
  // the game model for read-only rendering (null when not in a game)
  GammonState? _gameState;
  GammonState? get gameState => _gameState;

  // the raw FIBS board snapshot behind _gameState (turn, dice, names, canMove)
  FibsBoard? _board;
  FibsBoard? get board => _board;

  // set when the opponent doubles us and we must accept or reject
  var _doubleOffered = false;
  bool get doubleOffered => _doubleOffered;

  // opponents we have an unfinished, saved match with (from `show savedgames`).
  // A dropped connection (ours or theirs) saves the match; we can resume it.
  final _savedMatches = <String>{};
  List<String> get savedMatches => _savedMatches.toList(growable: false);

  // set when an opponent asks to resume a saved match with us (they invited);
  // we accept by calling [joinGame]. Cleared once a board arrives.
  String? _resumeRequestFrom;
  String? get resumeRequestFrom => _resumeRequestFrom;

  // set between games of a match (or to load a resumed match) when FIBS asks us
  // to type 'join' to continue. Cleared once a board arrives.
  var _mustJoin = false;
  bool get mustJoin => _mustJoin;

  // the dice we rolled this turn, captured from FIBS_YouRoll. FIBS doesn't
  // always re-send the board with our dice after a roll, so we track them here.
  var _myDice = <int>[];

  // transient "command in flight" flags so canRoll/canMoveNow stop being true
  // the instant we act (FIBS has moreboards off, so it does NOT echo a board
  // after our own roll/move). Without these, a caller would see the same
  // actionable state and fire the command again -> server-rejected junk.
  // _rolling: we sent `roll`, awaiting our dice (FIBS_YouRoll clears it).
  // _committedTurn: we sent a whole move, awaiting the next board.
  var _rolling = false;
  var _committedTurn = false;

  String? get user => _user;
  bool get connected => _conn.connected;

  // --- play state (only meaningful when we are a player, not just watching) --

  GammonPlayer? get myColor => _board == null || _user == null
      ? null
      : _board!.colorFor(_user!);

  bool get isMyTurn =>
      _board != null && myColor != null && _board!.turnPlayer == myColor;

  // the dice we have to play: the board's dice if present (e.g. the opening),
  // otherwise the dice we just rolled (FIBS_YouRoll)
  List<int> get _effectiveDice {
    if (_board == null) return const [];
    final boardDice = _board!.activeDice;
    if (boardDice.isNotEmpty) return boardDice;
    return isMyTurn ? _myDice : const [];
  }

  // it's our turn and we have dice and we haven't already committed this turn
  bool get canMoveNow =>
      isMyTurn && _effectiveDice.isNotEmpty && !_committedTurn;

  // it's our turn, no dice yet, and we haven't already rolled -> we must roll
  bool get canRoll =>
      isMyTurn && _effectiveDice.isEmpty && !_rolling && !_committedTurn;

  // A bot is identified by its reported CLIENT string, not its name. Live FIBS
  // data shows bots self-report a bot-framework client while humans report GUI
  // clients (3DFiBs, MGOnline, Padgammon, FIBzilla, ...). Name is unreliable
  // both ways: it misses bots like octopus/pubeval/wildbg and wrongly flags
  // TourneyBot (a tournament organizer). This is precision-first so we never
  // invite a human; it deliberately excludes bots that report no client (e.g.
  // MonteCarlo, client '-') -- add such names to [_knownBotNames] only once
  // confirmed.
  static const _botClients = <String>{
    'ParlorBot', // GammonBot / BlunderBot family
    'Computer_player', // octopus, pubeval, PureTD
    'bot_1p_matches_only', // wildbg, udacity_capstone
  };
  // Belt-and-suspenders for bots that might report no client (FIBS has no
  // protocol "isBot" flag). The client allowlist above already auto-catches the
  // whole live roster; these are confirmed exact bot names (from the live
  // who-list plus research against the fibs.com/bots.html and ParlorBot
  // rosters) so a known bot is still caught if its client field is missing.
  // MonteCarlo is the key case: a 1-point-match bot that reports no client.
  // Numbered variants (BlunderBot_IX, GammonBot_XV, ...) are covered by the
  // client allowlist, so only base/singleton names are listed. Names are unique
  // on FIBS, so exact-name matching never catches a human.
  static const _knownBotNames = <String>{
    'MonteCarlo',
    'BlunderBot',
    'GammonBot',
    'octopus',
    'pubeval',
    'PureTD',
    'wildbg',
  };

  static bool isBot(WhoInfo who) =>
      _botClients.contains(who.client) || _knownBotNames.contains(who.user);

  // optional observer of every incoming cookie (debugging / diagnostics)
  void Function(CookieMessage cm)? cookieObserver;

  void _streamItem(CookieMessage cm) {
    dev.log(cm.toString());
    cookieObserver?.call(cm);

    switch (cm.cookie) {
      // who
      case FibsCookie.CLIP_WHO_INFO:
        _addWho(WhoInfo.from(cm));
      case FibsCookie.CLIP_LOGOUT:
        _removeWho(cm.crumbs!['name']!);

      // messages
      case FibsCookie.CLIP_KIBITZES:
      case FibsCookie.CLIP_MESSAGE:
      case FibsCookie.CLIP_SAYS:
      case FibsCookie.CLIP_SHOUTS:
      case FibsCookie.CLIP_WHISPERS:
        messages.add(FibsMessage(
          cm.cookie,
          cm.crumbs!['name']!,
          cm.crumbs!['message']!,
        ));

      // we rolled: capture our dice (FIBS may not re-send the board with them)
      case FibsCookie.FIBS_YouRoll:
        final d1 = int.parse(cm.crumbs!['die1']!);
        final d2 = int.parse(cm.crumbs!['die2']!);
        _myDice = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
        _rolling = false; // our dice arrived; now we may move
        // A YouRoll proves it's OUR turn. FIBS sometimes sends it WITHOUT a
        // fresh board (e.g. when it auto-rolls for us after the opponent
        // dances), leaving the last board showing the opponent on roll -- which
        // would wrongly make the move generator play the opponent's checkers.
        // Reconcile the board's turn to ours.
        final me = myColor;
        if (me != null && _board != null && _board!.turnPlayer != me) {
          _board = _board!.copyWith(turnColor: me == GammonPlayer.one ? -1 : 1);
          _gameState = _board!.toGammonState();
        }
        notifyListeners();

      // gameplay: track the live board (render + play state)
      case FibsCookie.FIBS_Board:
        _board = FibsBoard.fromCrumbs(cm.crumbs!);
        _gameState = _board!.toGammonState();
        _doubleOffered = false; // a fresh board supersedes a pending offer
        _resumeRequestFrom = null; // we're in a game now
        _mustJoin = false;
        _committedTurn = false; // this board is the response to our move
        // A board is the AUTHORITATIVE dice state: its activeDice are our dice
        // for this turn (empty => we must roll). So drop any dice we captured
        // from a bare YouRoll -- otherwise stale dice from a prior turn make us
        // try to move on a fresh "your turn, no dice" board ("you have to roll
        // the dice before moving"). FIBS often reports the opponent's play as
        // text (PlayerMoves) and jumps straight to our roll board with no
        // intervening opponent-turn board, so we can't rely on a turn flip.
        _myDice = [];
        // Clear "we rolled, awaiting our dice" only when the turn has passed or
        // this board carries our dice; a same-state refresh keeps us awaiting
        // YouRoll so we don't roll twice.
        final notOurTurn = _board!.turnPlayer != myColor;
        if (notOurTurn || _board!.activeDice.isNotEmpty) _rolling = false;
        notifyListeners();

      // the opponent doubled us
      case FibsCookie.FIBS_AcceptRejectDouble:
        _doubleOffered = true;
        notifyListeners();

      // saved (unfinished) matches: a `show savedgames` listing, one per line
      case FibsCookie.FIBS_SavedMatch:
        final opp = cm.crumbs!['player1'];
        if (opp != null && opp.isNotEmpty) {
          _savedMatches.add(opp);
          notifyListeners();
        }
      case FibsCookie.FIBS_NoSavedGames:
        _savedMatches.clear();
        notifyListeners();

      // resume flow: an opponent asks to resume a saved match with us
      case FibsCookie.FIBS_ResumeMatchRequest:
        _resumeRequestFrom = cm.crumbs!['name'];
        notifyListeners();
      // FIBS asks us to type 'join' (load a resumed match / start next game)
      case FibsCookie.FIBS_JoinNextGame:
        _mustJoin = true;
        notifyListeners();
      // resume confirmed ("...running match was loaded"); a board will follow.
      // The opponent is no longer a pending saved match.
      case FibsCookie.FIBS_ResumeMatchAck0:
        _savedMatches.remove(cm.crumbs!['opponent']);
        notifyListeners();
      case FibsCookie.FIBS_ResumeMatchAck5:
        _savedMatches.remove(cm.crumbs!['opponent']);
        notifyListeners();

      // any other gameplay/lobby chatter is fine to ignore for now rather than
      // crash the stream (previously this threw)
      // ignore: no_default_cases
      default:
        break;
    }
  }

  // --- play actions (bots only) ---------------------------------------------

  // invite a bot to a match (precision-first: only bots). Default to a short
  // 3-point match so the doubling cube matters but games finish quickly.
  void invite(WhoInfo bot, {int matchLength = 3}) {
    assert(isBot(bot), 'bots only');
    _conn.send('invite ${bot.user} $matchLength');
  }

  // resume an unfinished match with [opponent]: inviting a player we have a
  // saved match with makes FIBS reload it instead of starting a new game. Good
  // citizenship (and connection-drop recovery) -- always finish saved matches.
  void resumeSavedMatch(String opponent) => _conn.send('invite $opponent');

  // continue a resumed/next game when FIBS asks us to type 'join' (also accepts
  // an opponent's resume request tracked in [resumeRequestFrom])
  void joinGame() {
    _conn.send('join');
    _mustJoin = false;
    _resumeRequestFrom = null;
  }

  // Roll the dice. Throws if it isn't our turn to roll (so a mis-timed call is
  // a loud bug, not a silently dropped command).
  void roll() {
    if (!canRoll) {
      throw FibsStateError('roll: not our turn to roll '
          '(isMyTurn=$isMyTurn rolling=$_rolling dice=$_effectiveDice)');
    }
    _rolling = true; // canRoll is now false until our dice arrive
    _conn.send('roll');
  }

  // move one checker one die at a time; the server validates (tap-to-move).
  // Throws if it isn't our turn to move.
  void move(int fromPip, int toPip) {
    if (!canMoveNow) {
      throw FibsStateError('move: not our turn to move '
          '(isMyTurn=$isMyTurn dice=$_effectiveDice '
          'committed=$_committedTurn)');
    }
    _conn.send(fibsRawMove(fromPip, toPip, myColor!));
  }

  // Play a legal move for us automatically (drives an assisted/auto game).
  // Picks the first legal move from the engine and sends it; returns the
  // command sent, or null if there's nothing to play. Bots-only, so safe to
  // automate.
  String? playFirstLegalMove() {
    if (!canMoveNow) {
      throw FibsStateError('playFirstLegalMove: not our turn to move '
          '(isMyTurn=$isMyTurn dice=$_effectiveDice '
          'committed=$_committedTurn)');
    }
    // FIBS wants the whole turn in one command; pick the best complete turn
    final cmd = FibsPlay.bestTurnCommand(_board!, dice: _effectiveDice) ??
        FibsPlay.fullTurnCommand(_board!, dice: _effectiveDice);
    // null == a legitimate dance (we have dice but no legal move): send nothing
    // and let FIBS auto-pass. That is NOT an error, so don't throw.
    if (cmd == null) return null;
    _committedTurn = true; // canMoveNow is now false until the next board
    _conn.send(cmd);
    return cmd;
  }

  void offerDouble() {
    if (!canRoll) {
      throw FibsStateError('offerDouble: can only double on our turn before '
          'rolling (isMyTurn=$isMyTurn dice=$_effectiveDice)');
    }
    _committedTurn = true; // we've acted this turn; await the response
    _conn.send('double');
  }

  void acceptDouble() {
    if (!_doubleOffered) {
      throw FibsStateError('acceptDouble: no double has been offered');
    }
    _conn.send('accept');
    _doubleOffered = false;
  }

  void rejectDouble() {
    if (!_doubleOffered) {
      throw FibsStateError('rejectDouble: no double has been offered');
    }
    _conn.send('reject');
    _doubleOffered = false;
  }

  void resign() => _conn.send('resign n'); // resign a normal loss

  void leaveGame() {
    _conn.send('leave');
    _board = null;
    _gameState = null;
    _myDice = [];
    _rolling = false;
    _committedTurn = false;
    notifyListeners();
  }

  // bots that are free to play (invite targets): bot client, ready, not in a
  // game. Precision-first so we only ever invite a bot, never a human.
  List<WhoInfo> get availableBots => [
        for (final who in whoInfos)
          if (isBot(who) && who.ready && who.opponent.isEmpty) who,
      ];

  // bots currently in a game that can be watched (their opponent may be human,
  // which is fine for watching)
  List<WhoInfo> get watchableBots => [
        for (final who in whoInfos)
          if (isBot(who) && who.opponent.isNotEmpty) who,
      ];

  void watch(WhoInfo who) {
    assert(isBot(who), 'bots only');
    _board = null;
    _gameState = null;
    _myDice = [];
    _conn.send('watch ${who.user}');
    notifyListeners();
  }

  void stopWatching() {
    _conn.send('unwatch');
    _board = null;
    _gameState = null;
    _myDice = [];
    notifyListeners();
  }

  bool get loggedIn => _conn.connected;

  Future<void> login({required String user, required String pass}) async {
    assert(!loggedIn);

    _conn.stream.listen(_streamItem, onDone: _reset);
    final cookie = await _conn.login(user, pass).timeout(
        const Duration(seconds: 3),
        onTimeout: () => FibsCookie.FIBS_Timeout);
    if (cookie != FibsCookie.CLIP_WELCOME) {
      await _conn.close();
      throw Exception(cookie == FibsCookie.FIBS_Timeout
          ? 'unable to connect; check your internet connection'
          : 'invalid user name and password');
    }

    _user = user;
    // raw board frames are required for parsing; moreboards is toggled on from
    // CLIP_OWN_INFO below so FIBS sends a board after every roll/move
    _conn.send('set boardstyle 3');
    // Explicitly request the who-list. FIBS pushes it automatically on a fresh
    // login, but not reliably on a quick reconnect -- asking for it makes the
    // bot list populate every time instead of sometimes hanging on "waiting for
    // the who-list".
    _conn.send('who');
    // FIBS automatically lists our unfinished saved matches right after login
    // (the FIBS_SavedMatch lines handled in _streamItem), so there's no command
    // to send -- a dropped connection (ours or the opponent's) saves the match
    // and we resume it by re-inviting.
    notifyListeners();
  }

  Future<void> logout() async {
    if (loggedIn) _conn.send('bye');
    // an explicit logout means "don't auto-reconnect": forget the remembered
    // password so the next launch shows the login screen instead of signing
    // back in. (Closing the tab is a different thing -- it keeps remember.)
    final prefs = App.prefs.value;
    if (prefs != null) {
      await prefs.setBool('autologin', false);
      await prefs.setBool('remember', false);
      await prefs.remove('pass');
    }
    _reset();
  }

  void _reset() {
    whoInfos.clear();
    messages.clear();
    _user = null;
    _board = null;
    _gameState = null;
    _myDice = [];
    _doubleOffered = false;
    _savedMatches.clear();
    _resumeRequestFrom = null;
    _mustJoin = false;
    _rolling = false;
    _committedTurn = false;
    notifyListeners();
  }

  void _addWho(WhoInfo whoInfo) {
    _removeWho(whoInfo.user);
    whoInfos.add(whoInfo);
  }

  void _removeWho(String user) {
    for (var i = 0; i != whoInfos.length; ++i) {
      if (whoInfos[i].user == user) {
        whoInfos.removeAt(i);
        break;
      }
    }
  }

  void send(String cmd) => _conn.send(cmd);
}

// flutter: {
//  cookie: FibsCookie.CLIP_WHO_INFO,
//
//  crumbs: {
//    name: chris,
//    opponent: -,
//    watching: -,
//    ready: 1,
//    away: 0,
//    rating: 1500.0,
//    experience: 0,
//    idle: 0,
//    login: 1601853512515,
//    hostName: localhost,
//    client: flutter-fibs,
//    email: -
//  }
//
// name: 	The login name for the user this line is referring to.
//
// opponent: 	The login name of the person the user is currently playing
//  against, or a hyphen if they are not playing anyone.
//
// watching: 	The login name of the person the user is currently watching,
//  or a hyphen if they are not watching anyone.
//
// ready: 	1 if the user is ready to start playing, 0 if not.
//  Note that the ready status can be set to 1 even while the user is playing
//  a game and thus, technically unavailable. Refer to Toggle Ready.
//
// away: 	1 for yes, 0 for no. Refer to Away.
//
// rating: 	The user's rating as a number with two decimal places.
//
// experience: 	The user's experience.
//
// idle: 	The number of seconds the user has been idle.
//
// login: 	The time the user logged in as the number of seconds since
//  midnight, January 1, 1970 UTC.
//
// hostname: 	The host name or IP address the user is logged in from.
//  Note that the host name can change from an IP address to a host name due
//  to the way FIBS host name resolving works.
//
// client: 	The client the user is using (see login) or a hyphen if not
//  specified. See notes below.
//
// email: 	The user's email address, or a hyphen if not specified.
//  Refer to Address.
class WhoInfo {
  WhoInfo({
    required this.user,
    required this.opponent,
    required this.watching,
    required this.ready,
    required this.away,
    required this.rating,
    required this.experience,
    required this.lastActive,
    required this.lastLogin,
    required this.hostname,
    required this.client,
    required this.email,
  });

  factory WhoInfo.from(CookieMessage cm) {
    assert(cm.cookie == FibsCookie.CLIP_WHO_INFO);
    return WhoInfo(
      user: cm.crumbs!['name']!,
      opponent: CookieMonster.parseOptional(cm.crumbs!['opponent']!) ?? '',
      watching: CookieMonster.parseOptional(cm.crumbs!['watching']!) ?? '',
      ready: CookieMonster.parseBool(cm.crumbs!['ready']),
      away: CookieMonster.parseBool(cm.crumbs!['away']),
      rating: double.parse(cm.crumbs!['rating']!),
      experience: int.parse(cm.crumbs!['experience']!),
      lastActive:
          DateTime.now().add(Duration(seconds: int.parse(cm.crumbs!['idle']!))),
      lastLogin: CookieMonster.parseTimestamp(cm.crumbs!['login']!),
      hostname: cm.crumbs!['hostname'] ?? '',
      client: CookieMonster.parseOptional(cm.crumbs!['client']!) ?? '',
      email: CookieMonster.parseOptional(cm.crumbs!['email']!) ?? '',
    );
  }
  final String user;
  final String opponent;
  final String watching;
  final bool ready;
  final bool away;
  final double rating;
  final int experience;
  final DateTime lastActive;
  final DateTime lastLogin;
  final String hostname;
  final String client;
  final String email;
}
