import 'dart:async';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'bot_policy.dart';
import 'fibs_board.dart';
import 'fibs_lobby.dart';
import 'fibs_move.dart';
import 'fibs_play.dart';
import 'fibs_session.dart';
import 'fibs_transport.dart';
import 'model.dart';
import 'tinystate.dart';

// WhoInfo/FibsLobby moved to fibs_lobby.dart; re-export so importers of
// fibs_state (the UI, tests) still see WhoInfo unchanged.
export 'fibs_lobby.dart' show FibsLobby, WhoInfo;

final _log = Logger('fibs');

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

  // the chat-style cookies a FibsMessage is ever built from -> a display verb
  static const _cookieNames = <FibsCookie, String>{
    FibsCookie.CLIP_KIBITZES: 'kibitzes',
    FibsCookie.CLIP_SAYS: 'says',
    FibsCookie.CLIP_SHOUTS: 'shouts',
    FibsCookie.CLIP_WHISPERS: 'whispers',
  };

  String get _cookieName => _cookieNames[cookie] ?? cookie.name;
}

class FibsState extends ChangeNotifier {
  // The proxy host/port the websocat bridge listens on (see README). Defaults
  // to the local bridge; overridable so tooling can target 127.0.0.1 directly.
  FibsState({String proxy = 'localhost', int port = 8080})
    : _conn = FibsConnectionTransport(FibsConnection(proxy, port));

  // Inject a transport (e.g. a fake) to drive the state without a live server.
  FibsState.withTransport(this._conn);

  // the FIBS lobby roster (who-list + bot-only invite/watch queries)
  final lobby = FibsLobby();
  NotifierList<WhoInfo> get whoInfos => lobby.entries;
  final messages = NotifierList<FibsMessage>();
  final FibsTransport _conn;
  StreamSubscription<CookieMessage>? _sub;

  // the immutable game/turn state machine: inbound cookies and our own actions
  // both fold into it, and every display value below is DERIVED from it -- one
  // source of truth instead of a dozen mutable flags (see fibs_session.dart).
  var _session = const FibsSession();

  // Called on EXPLICIT logout only (not tab-close or a dropped connection), so
  // the app can run end-of-session cleanup (e.g. forgetting a remembered
  // password) without FibsState having to know about credentials. Injected by
  // the app in bootstrap; null in tests that don't care.
  Future<void> Function()? onLogout;

  // the game model for rendering, derived from the session (null when not in a
  // game); the raw FIBS board snapshot behind it (turn, dice, names, canMove)
  GammonState? get gameState => _session.gameState;
  FibsBoard? get board => _session.board;

  bool get doubleOffered => _session.doubleOffered;
  List<String> get savedMatches =>
      _session.savedMatches.toList(growable: false);
  String? get resumeRequestFrom => _session.resumeRequestFrom;
  bool get mustJoin => _session.mustJoin;

  String? get user => _session.user;
  bool get connected => _conn.connected;

  // --- play state (only meaningful when we are a player, not just watching) --

  GammonPlayer? get myColor => _session.myColor;
  bool get isMyTurn => _session.isMyTurn;

  // The dice the UI should display/play -- the board's dice, or the ones we
  // just rolled when FIBS delivered them via a "You roll x and y" message
  // without a fresh board carrying them.
  List<int> get activeDice => _session.effectiveDice;

  bool get canMoveNow => _session.canMoveNow;
  bool get canRoll => _session.canRoll;

  // Whether a who-list entry is a bot. The detection policy (allowlists +
  // precision-first rationale) lives in BotPolicy so it can evolve without
  // touching this connection/state machine.
  static bool isBot(WhoInfo who) =>
      BotPolicy.isBot(client: who.client, user: who.user);

  // optional observer of every incoming cookie (debugging / diagnostics)
  void Function(CookieMessage cm)? cookieObserver;

  void _streamItem(CookieMessage cm) {
    // log only the cookie TYPE -- the crumbs/raw carry other users' PII
    // (who-list emails, chat text). Full content goes only to the opt-in,
    // local trace via cookieObserver (e.g. the live e2e), never the app log.
    _log.finer(cm.cookie.name);
    cookieObserver?.call(cm);
    // Dispatch by cookie; any other gameplay/lobby chatter is ignored (no
    // handler) rather than crashing the stream.
    _handlers[cm.cookie]?.call(cm);
  }

  // Cookie -> handler. Lobby and chat are growing collections with their own
  // notifiers, so they stay here; every game/turn cookie folds into the pure
  // session reducer via _applyCookie (one place, one source of truth).
  late final Map<FibsCookie, void Function(CookieMessage)> _handlers = {
    FibsCookie.CLIP_WHO_INFO: (cm) => lobby.upsert(WhoInfo.from(cm)),
    FibsCookie.CLIP_LOGOUT: (cm) => lobby.remove(cm.crumbs!['name']!),
    FibsCookie.CLIP_KIBITZES: _onChatMessage,
    FibsCookie.CLIP_MESSAGE: _onChatMessage,
    FibsCookie.CLIP_SAYS: _onChatMessage,
    FibsCookie.CLIP_SHOUTS: _onChatMessage,
    FibsCookie.CLIP_WHISPERS: _onChatMessage,
    FibsCookie.FIBS_YouRoll: _applyCookie,
    FibsCookie.FIBS_Board: _applyCookie,
    FibsCookie.FIBS_AcceptRejectDouble: _applyCookie,
    FibsCookie.FIBS_SavedMatch: _applyCookie,
    FibsCookie.FIBS_NoSavedGames: _applyCookie,
    FibsCookie.FIBS_ResumeMatchRequest: _applyCookie,
    FibsCookie.FIBS_JoinNextGame: _applyCookie,
    FibsCookie.FIBS_ResumeMatchAck0: _applyCookie,
    FibsCookie.FIBS_ResumeMatchAck5: _applyCookie,
  };

  // fold an inbound game/turn cookie into the session and republish
  void _applyCookie(CookieMessage cm) {
    _session = _session.reduce(cm);
    notifyListeners();
  }

  void _onChatMessage(CookieMessage cm) => messages.add(
    FibsMessage(cm.cookie, cm.crumbs!['name']!, cm.crumbs!['message']!),
  );

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
    _session = _session.joined();
  }

  // Roll the dice. Throws if it isn't our turn to roll (so a mis-timed call is
  // a loud bug, not a silently dropped command).
  void roll() {
    if (!canRoll) {
      throw FibsStateError(
        'roll: not our turn to roll '
        '(isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    _session = _session.startedRolling(); // canRoll false until our dice arrive
    _conn.send('roll');
  }

  // move one checker one die at a time; the server validates (tap-to-move).
  // Throws if it isn't our turn to move.
  void move(int fromPip, int toPip) {
    if (!canMoveNow) {
      throw FibsStateError(
        'move: not our turn to move (isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    _conn.send(fibsRawMove(fromPip, toPip, myColor!));
  }

  // Play a legal move for us automatically (drives an assisted/auto game).
  // Picks the first legal move from the engine and sends it; returns the
  // command sent, or null if there's nothing to play. Bots-only, so safe to
  // automate.
  String? playFirstLegalMove() {
    if (!canMoveNow) {
      throw FibsStateError(
        'playFirstLegalMove: not our turn to move '
        '(isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    // FIBS wants the whole turn in one command; pick the best complete turn
    final cmd =
        FibsPlay.bestTurnCommand(board!, dice: activeDice) ??
        FibsPlay.fullTurnCommand(board!, dice: activeDice);
    // null == a legitimate dance (we have dice but no legal move): send nothing
    // and let FIBS auto-pass. That is NOT an error, so don't throw.
    if (cmd == null) return null;
    _session = _session.committed(); // canMoveNow false until the next board
    _conn.send(cmd);
    return cmd;
  }

  void offerDouble() {
    if (!canRoll) {
      throw FibsStateError(
        'offerDouble: can only double on our turn before '
        'rolling (isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    _session = _session
        .committed(); // we've acted this turn; await the response
    _conn.send('double');
  }

  void acceptDouble() {
    if (!doubleOffered) {
      throw FibsStateError('acceptDouble: no double has been offered');
    }
    _conn.send('accept');
    _session = _session.doubleResolved();
  }

  void rejectDouble() {
    if (!doubleOffered) {
      throw FibsStateError('rejectDouble: no double has been offered');
    }
    _conn.send('reject');
    _session = _session.doubleResolved();
  }

  void resign() => _conn.send('resign n'); // resign a normal loss

  void leaveGame() {
    _conn.send('leave');
    _session = _session.outOfGame();
    notifyListeners();
  }

  // free bot invite targets / watchable in-game bots (delegated to the lobby)
  List<WhoInfo> get availableBots => lobby.availableBots;
  List<WhoInfo> get watchableBots => lobby.watchableBots;

  void watch(WhoInfo who) {
    assert(isBot(who), 'bots only');
    _session = _session.outOfGame();
    _conn.send('watch ${who.user}');
    notifyListeners();
  }

  void stopWatching() {
    _conn.send('unwatch');
    _session = _session.outOfGame();
    notifyListeners();
  }

  bool get loggedIn => _conn.connected;

  Future<void> login({required String user, required String pass}) async {
    assert(!loggedIn);

    _sub = _conn.stream.listen(
      _streamItem,
      onError: _onStreamError,
      onDone: _reset,
    );
    final cookie = await _conn
        .login(user, pass)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => FibsCookie.FIBS_Timeout,
        );
    if (cookie != FibsCookie.CLIP_WELCOME) {
      await _conn.close();
      throw Exception(
        cookie == FibsCookie.FIBS_Timeout
            ? 'unable to connect; check your internet connection'
            : 'invalid user name and password',
      );
    }

    _session = _session.loggedInAs(user);
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
    // an explicit logout means "don't auto-reconnect": let the app forget the
    // remembered password so the next launch shows the login screen instead of
    // signing back in. (Closing the tab is a different thing -- it keeps
    // remember -- so this hook fires only here, never on tab-close/drop.)
    await onLogout?.call();
    await _sub?.cancel();
    _sub = null;
    await _conn
        .close(); // actually tear the connection down (no lingering socket)
    _reset();
  }

  // A mid-session transport failure: surface it to the log and reset the
  // session rather than letting it escape as an unhandled async error.
  void _onStreamError(Object error, StackTrace stackTrace) {
    _log.warning('FIBS stream error', error, stackTrace);
    _reset();
  }

  void _reset() {
    lobby.clear();
    messages.clear();
    _session = const FibsSession();
    notifyListeners();
  }

  void send(String cmd) => _conn.send(cmd);
}
