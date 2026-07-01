import 'dart:async';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'bot_policy.dart';
import 'fibs_board.dart';
import 'fibs_crumb_keys.dart';
import 'fibs_lobby.dart';
import 'fibs_move.dart';
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
    : _makeTransport = (() =>
          FibsConnectionTransport(FibsConnection(proxy, port)));

  // Inject a transport (e.g. a fake) to drive the state without a live server.
  FibsState.withTransport(FibsTransport transport)
    : _makeTransport = (() => transport);

  // Inject a transport FACTORY -- a fresh transport per login() -- so tests can
  // exercise reconnect / re-login with production-like (single-subscription,
  // real-close) transport semantics, which a single reused fake would hide.
  FibsState.withTransportFactory(this._makeTransport);

  // the FIBS lobby roster (who-list + bot-only invite/watch queries)
  final lobby = FibsLobby();
  NotifierList<WhoInfo> get whoInfos => lobby.entries;
  final messages = NotifierList<FibsMessage>();
  // A connection isn't reusable once closed (its stream controller is closed
  // for good), so we build a FRESH transport per login instead of reusing one
  // for the app's lifetime. Null before the first login / after teardown.
  final FibsTransport Function() _makeTransport;
  FibsTransport? _conn;
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
  bool get connected => _conn?.connected ?? false;

  // --- play state (only meaningful when we are a player, not just watching) --

  GammonPlayer? get myColor => _session.myColor;
  bool get isMyTurn => _session.isMyTurn;

  // The dice the UI should display/play -- the board's dice, or the ones we
  // just rolled when FIBS delivered them via a "You roll x and y" message
  // without a fresh board carrying them.
  List<int> get activeDice => _session.effectiveDice;

  bool get canMoveNow => _session.canMoveNow;
  bool get canRoll => _session.canRoll;

  // The current game has finished (FIBS announced a result, or 15 borne off).
  bool get isGameOver => _session.isGameOver;

  // Whether WE won the finished game (false = the opponent won). Null while a
  // game is in progress. Prefers FIBS's announced result, falling back to the
  // board's borne-off winner.
  bool? get didIWin {
    if (_session.iWon != null) return _session.iWon;
    final winner = _session.board?.winner;
    return winner == null ? null : winner == _session.myColor;
  }

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
    FibsCookie.CLIP_LOGOUT: (cm) => lobby.remove(cm.crumb(FibsCrumbKeys.name)),
    FibsCookie.CLIP_KIBITZES: _onChatMessage,
    FibsCookie.CLIP_MESSAGE: _onChatMessage,
    FibsCookie.CLIP_SAYS: _onChatMessage,
    FibsCookie.CLIP_SHOUTS: _onChatMessage,
    FibsCookie.CLIP_WHISPERS: _onChatMessage,
    FibsCookie.FIBS_YouRoll: _applyCookie,
    FibsCookie.FIBS_Board: _applyCookie,
    // game/match results: FIBS announces the winner as a text message, so these
    // are what actually ends the game in the UI (a 15-off board never arrives).
    // Includes resignation outcomes.
    FibsCookie.FIBS_YouWinGame: _applyCookie,
    FibsCookie.FIBS_PlayerWinsGame: _applyCookie,
    FibsCookie.FIBS_YouWinMatch: _applyCookie,
    FibsCookie.FIBS_PlayerWinsMatch: _applyCookie,
    FibsCookie.FIBS_ResignYouWin: _applyCookie,
    FibsCookie.FIBS_YouAcceptAndWin: _applyCookie,
    FibsCookie.FIBS_AcceptWins: _applyCookie,
    FibsCookie.FIBS_ResignWins: _applyCookie,
    // a watched game finished -> we were only spectating, so drop to the lobby
    FibsCookie.FIBS_WatchGameWins: (_) => returnToLobby(),
    FibsCookie.FIBS_AcceptRejectDouble: _applyCookie,
    FibsCookie.FIBS_SavedMatch: _applyCookie,
    FibsCookie.FIBS_NoSavedGames: _applyCookie,
    // an opponent asking to resume, or FIBS prompting "type join" between/into
    // games, both need a `join` to actually load the board -- auto-join so an
    // outstanding game ALWAYS drops us back in, no tap required.
    FibsCookie.FIBS_ResumeMatchRequest: _applyAndAutoJoin,
    FibsCookie.FIBS_JoinNextGame: _applyAndAutoJoin,
    FibsCookie.FIBS_ResumeMatchAck0: _applyCookie,
    FibsCookie.FIBS_ResumeMatchAck5: _applyCookie,
  };

  // fold an inbound game/turn cookie into the session and republish
  void _applyCookie(CookieMessage cm) {
    _session = _session.reduce(cm);
    notifyListeners();
  }

  // Reduce a resume/join prompt and immediately send `join` so the saved game
  // loads on its own. FIBS sometimes reloads the match and sends a board
  // directly; otherwise it waits for a `join`, which this sends automatically.
  void _applyAndAutoJoin(CookieMessage cm) {
    _session = _session.reduce(cm);
    if (_session.mustJoin || _session.resumeRequestFrom != null) {
      joinGame(); // sends `join` and clears the prompt
    }
    notifyListeners();
  }

  void _onChatMessage(CookieMessage cm) => messages.add(
    FibsMessage(
      cm.cookie,
      cm.crumb(FibsCrumbKeys.name),
      cm.crumb(FibsCrumbKeys.message),
    ),
  );

  // --- play actions (bots only) ---------------------------------------------

  // invite a bot to a match (precision-first: only bots). Default to a short
  // 3-point match so the doubling cube matters but games finish quickly.
  void invite(WhoInfo bot, {int matchLength = 3}) {
    assert(isBot(bot), 'bots only');
    _conn?.send('invite ${bot.user} $matchLength');
  }

  // resume an unfinished match with [opponent]: inviting a player we have a
  // saved match with makes FIBS reload it instead of starting a new game. Good
  // citizenship (and connection-drop recovery) -- always finish saved matches.
  void resumeSavedMatch(String opponent) => _conn?.send('invite $opponent');

  // continue a resumed/next game when FIBS asks us to type 'join' (also accepts
  // an opponent's resume request tracked in [resumeRequestFrom])
  void joinGame() {
    _conn?.send('join');
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
    _conn?.send('roll');
  }

  // Submit a WHOLE turn the player built locally on the shared board (the same
  // mechanic as the local game: make your moves, undo freely, then tap the dice
  // to commit). FIBS wants the complete turn in one command, so we send it all
  // at once -- a partial turn is what triggers "** You must give N moves". The
  // moves are in viewer pips (player one); an empty list is a dance (pass).
  void submitTurn(List<GammonMove> moves) {
    if (!canMoveNow) {
      throw FibsStateError(
        'submitTurn: not our turn to move '
        '(isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    _session = _session.committed(); // canMoveNow off until the next board
    // an empty turn is a dance: FIBS auto-passes, so there's nothing to send.
    if (moves.isNotEmpty) _conn?.send(fibsTurnCommand(moves));
  }

  // Send a pre-built whole-turn `move ...` [command] and mark the turn
  // committed (canMoveNow off until the next board). This is pure transport:
  // the POLICY of WHICH turn to play (pubeval / an AI engine) lives in the
  // caller -- e.g. FibsBotPlayer -- so this connection/state machine stays free
  // of move selection. Throws if it isn't our turn to move.
  void commitTurnCommand(String command) {
    if (!canMoveNow) {
      throw FibsStateError(
        'commitTurnCommand: not our turn to move '
        '(isMyTurn=$isMyTurn dice=$activeDice)',
      );
    }
    _session = _session.committed(); // canMoveNow false until the next board
    _conn?.send(command);
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
    _conn?.send('double');
  }

  void acceptDouble() {
    if (!doubleOffered) {
      throw FibsStateError('acceptDouble: no double has been offered');
    }
    _conn?.send('accept');
    _session = _session.doubleResolved();
  }

  void rejectDouble() {
    if (!doubleOffered) {
      throw FibsStateError('rejectDouble: no double has been offered');
    }
    _conn?.send('reject');
    _session = _session.doubleResolved();
  }

  void resign() => _conn?.send('resign n'); // resign a normal loss

  void leaveGame() {
    _conn?.send('leave');
    _session = _session.outOfGame();
    notifyListeners();
  }

  // Dismiss a finished game and return to the lobby. The game is already over
  // server-side, so there's nothing to `leave` -- just clear the local board.
  void returnToLobby() {
    _session = _session.outOfGame();
    notifyListeners();
  }

  // free bot invite targets / watchable in-game bots (delegated to the lobby)
  List<WhoInfo> get availableBots => lobby.availableBots;
  List<WhoInfo> get watchableBots => lobby.watchableBots;

  void watch(WhoInfo who) {
    assert(isBot(who), 'bots only');
    _session = _session.outOfGame();
    _conn?.send('watch ${who.user}');
    notifyListeners();
  }

  void stopWatching() {
    _conn?.send('unwatch');
    _session = _session.outOfGame();
    notifyListeners();
  }

  bool get loggedIn => _conn?.connected ?? false;

  // One-shot autologin guard: the login view attempts a remembered-credentials
  // autologin at most once per session. Without this, a connection that drops
  // right after login (e.g. FIBS kicking a duplicate login) recreates the login
  // view, which re-fires autologin, which reconnects and gets dropped again --
  // an infinite login<->lobby flash. An explicit logout re-arms it.
  bool _autoLoginTried = false;
  bool get autoLoginTried => _autoLoginTried;

  // True while WE are deliberately closing the connection (logout), so the
  // resulting onDone/onError is silent. An unexpected drop (server kick, network
  // loss) surfaces a "connection lost" notice instead of silently dumping the
  // user back on the login screen.
  bool _expectClose = false;
  void markAutoLoginTried() => _autoLoginTried = true;

  Future<void> login({required String user, required String pass}) async {
    assert(!loggedIn);

    // A connection can't be reused once closed, so build a FRESH transport per
    // login -- this is what makes retry-after-failed-login and login-after-
    // logout work. Drop any stale subscription first.
    await _sub?.cancel();
    _expectClose = false; // a fresh connection: a drop from here is unexpected
    final conn = _makeTransport();
    _conn = conn;
    _sub = conn.stream.listen(
      _streamItem,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
    final cookie = await conn
        .login(user, pass)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => FibsCookie.FIBS_Timeout,
        );
    if (cookie != FibsCookie.CLIP_WELCOME) {
      await _sub?.cancel(); // don't leave the failed session's listener live
      _sub = null;
      await conn.close();
      throw Exception(
        cookie == FibsCookie.FIBS_Timeout
            ? 'unable to connect; check your internet connection'
            : 'invalid user name and password',
      );
    }

    _session = _session.loggedInAs(user);
    // raw board frames are required for parsing; moreboards is toggled on from
    // CLIP_OWN_INFO below so FIBS sends a board after every roll/move
    _conn?.send('set boardstyle 3');
    // Explicitly request the who-list. FIBS pushes it automatically on a fresh
    // login, but not reliably on a quick reconnect -- asking for it makes the
    // bot list populate every time instead of sometimes hanging on "waiting for
    // the who-list".
    _conn?.send('who');
    // Ask FIBS for our unfinished saved matches. FIBS does NOT volunteer the
    // listing on login -- you have to request it -- and its lines (handled as
    // FIBS_SavedMatch) populate savedMatches so the lobby can offer "Resume a
    // saved match". (FIBS never re-invites you itself; resuming re-invites the
    // opponent, which makes FIBS reload the saved game.)
    _conn?.send('show savedgames');
    notifyListeners();
  }

  Future<void> logout() async {
    final conn = _conn;
    if (loggedIn) conn?.send('bye');
    // an explicit logout means "don't auto-reconnect": let the app forget the
    // remembered password so the next launch shows the login screen instead of
    // signing back in. (Closing the tab is a different thing -- it keeps
    // remember -- so this hook fires only here, never on tab-close/drop.)
    //
    // Guard the hook: a secure-storage failure (locked keychain, missing
    // libsecret, web-crypto hiccup) must NOT abort teardown and orphan the
    // socket -- tearing the connection down is the more important half.
    _expectClose = true; // a deliberate close: the ensuing onDone stays silent
    try {
      await onLogout?.call();
    } on Object catch (ex, st) {
      _log.warning('logout hook failed; tearing down anyway', ex, st);
    }
    await _sub?.cancel();
    _sub = null;
    await conn
        ?.close(); // actually tear the connection down (no lingering socket)
    _autoLoginTried = false; // a deliberate logout re-arms autologin
    _reset();
  }

  // The connection closed. If WE didn't ask for it (server kick, network loss),
  // tell the user rather than silently dumping them on the login screen.
  void _onStreamDone() {
    final unexpected = !_expectClose;
    _reset();
    if (unexpected) _surfaceConnectionLost('Connection to FIBS lost.');
  }

  // A mid-session transport failure: log it, reset, and (if unexpected) surface
  // it rather than letting it escape as an unhandled async error.
  void _onStreamError(Object error, StackTrace stackTrace) {
    _log.warning('FIBS stream error', error, stackTrace);
    final unexpected = !_expectClose;
    _reset();
    if (unexpected) _surfaceConnectionLost('FIBS connection error.');
  }

  // Post a notice AFTER _reset (which clears messages) so the user sees why the
  // session ended. Shown by FibsPage's message SnackBar over the login screen.
  void _surfaceConnectionLost(String text) => messages.add(
    FibsMessage(FibsCookie.FIBS_Unknown, 'FIBS', '$text Please log in again.'),
  );

  void _reset() {
    lobby.clear();
    messages.clear();
    _session = const FibsSession();
    notifyListeners();
  }

  void send(String cmd) => _conn?.send(cmd);
}
