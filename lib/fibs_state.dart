import 'dart:developer' as dev;

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';

import 'fibs_board.dart';
import 'fibs_move.dart';
import 'fibs_play.dart';
import 'main.dart';
import 'model.dart';
import 'tinystate.dart';

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
      : _conn = FibsConnection(proxy, port);

  final whoInfos = NotifierList<WhoInfo>();
  final messages = NotifierList<FibsMessage>();
  final FibsConnection _conn;
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

  // the dice we rolled this turn, captured from FIBS_YouRoll. FIBS doesn't
  // always re-send the board with our dice after a roll, so we track them here.
  var _myDice = <int>[];

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

  // it's our turn and we have dice and checkers we may move
  bool get canMoveNow => isMyTurn && _effectiveDice.isNotEmpty;

  // it's our turn but no dice yet -> we must roll (or double)
  bool get canRoll => isMyTurn && _effectiveDice.isEmpty;

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
        notifyListeners();

      // gameplay: track the live board (render + play state)
      case FibsCookie.FIBS_Board:
        _board = FibsBoard.fromCrumbs(cm.crumbs!);
        _gameState = _board!.toGammonState();
        _doubleOffered = false; // a fresh board supersedes a pending offer
        // our rolled dice only apply while it's our turn; clear once it isn't
        if (_board!.turnPlayer != myColor) _myDice = [];
        notifyListeners();

      // the opponent doubled us
      case FibsCookie.FIBS_AcceptRejectDouble:
        _doubleOffered = true;
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

  void roll() => _conn.send('roll');

  // move one checker one die at a time; the server validates (tap-to-move)
  void move(int fromPip, int toPip) {
    final me = myColor;
    if (me == null) return;
    _conn.send(fibsRawMove(fromPip, toPip, me));
  }

  // Play a legal move for us automatically (drives an assisted/auto game).
  // Picks the first legal move from the engine and sends it; returns the
  // command sent, or null if there's nothing to play. Bots-only, so safe to
  // automate.
  String? playFirstLegalMove() {
    if (_board == null || !canMoveNow) return null;
    // FIBS wants the whole turn in one command; pick the best complete turn
    final cmd = FibsPlay.bestTurnCommand(_board!, dice: _effectiveDice) ??
        FibsPlay.fullTurnCommand(_board!, dice: _effectiveDice);
    if (cmd == null) return null;
    _conn.send(cmd);
    return cmd;
  }

  void offerDouble() => _conn.send('double');
  void acceptDouble() {
    _conn.send('accept');
    _doubleOffered = false;
  }

  void rejectDouble() {
    _conn.send('reject');
    _doubleOffered = false;
  }

  void resign() => _conn.send('resign n'); // resign a normal loss

  void leaveGame() {
    _conn.send('leave');
    _board = null;
    _gameState = null;
    _myDice = [];
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
    notifyListeners();
  }

  Future<void> logout() async {
    if (loggedIn) _conn.send('bye');
    await App.prefs.value!.setBool('autologin', false);
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
