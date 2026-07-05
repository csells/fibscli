import 'dart:async';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'analytics.dart';
import 'bot_policy.dart';
import 'fibs_board.dart';
import 'fibs_crumb_keys.dart';
import 'fibs_lobby.dart';
import 'fibs_move.dart';
import 'fibs_resume_coordinator.dart';
import 'fibs_saved_match_display.dart';
import 'fibs_session.dart';
import 'fibs_transport.dart';
import 'model.dart';
import 'tinystate.dart';

// WhoInfo/FibsLobby moved to fibs_lobby.dart; re-export so importers of
// fibs_state (the UI, tests) still see WhoInfo unchanged.
export 'fibs_lobby.dart' show FibsLobby, WhoInfo;
export 'fibs_resume_coordinator.dart' show ResumeDelayInfo;
export 'fibs_saved_match_display.dart'
    show SavedMatchDisplay, SavedMatchDisplayState;
export 'fibs_session.dart' show SavedMatchAvailability, SavedMatchInfo;

part 'fibs_state_actions.dart';

final _log = Logger('fibs');

const _commandRejectedCookies = {
  FibsCookie.FIBS_BadMove,
  FibsCookie.FIBS_CantMoveFirstMove,
  FibsCookie.FIBS_MustComeIn,
  FibsCookie.FIBS_MustMove,
};

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
  // The app's hosted WebSocket-to-FIBS bridge. Compile-time overrides are for
  // development, staging, and live test infrastructure; the UI never exposes
  // proxy selection.
  FibsState({
    String? proxy,
    int? port,
    bool? secure,
    String? path,
    AppAnalytics? analytics,
    Duration? loginTimeout,
  }) : analytics = analytics ?? AppAnalytics.disabled(),
       _loginTimeout = loginTimeout ?? _defaultLoginTimeout,
       _makeTransport = (() => FibsConnectionTransport(
         FibsConnection(
           proxy ?? _envProxyHost,
           port ?? _envProxyPort,
           secure: secure ?? _envProxySecure,
           path: path ?? _envProxyPath,
         ),
       ));

  // Inject a transport (e.g. a fake) to drive the state without a live server.
  FibsState.withTransport(
    FibsTransport transport, {
    AppAnalytics? analytics,
    Duration? loginTimeout,
  }) : analytics = analytics ?? AppAnalytics.disabled(),
       _loginTimeout = loginTimeout ?? _defaultLoginTimeout,
       _makeTransport = (() => transport);

  // Inject a transport FACTORY -- a fresh transport per login() -- so tests can
  // exercise reconnect / re-login with production-like (single-subscription,
  // real-close) transport semantics, which a single reused fake would hide.
  FibsState.withTransportFactory(
    this._makeTransport, {
    AppAnalytics? analytics,
    Duration? loginTimeout,
  }) : analytics = analytics ?? AppAnalytics.disabled(),
       _loginTimeout = loginTimeout ?? _defaultLoginTimeout;

  static const _defaultLoginTimeout = Duration(seconds: 15);

  // ignore: do_not_use_environment -- compile-time proxy config seam
  static const _envProxyHost = String.fromEnvironment(
    'fibs_proxy_host',
    defaultValue: 'proxy.playfibs.com',
  );
  // ignore: do_not_use_environment -- compile-time proxy config seam
  static const _envProxyPort = int.fromEnvironment(
    'fibs_proxy_port',
    defaultValue: 443,
  );
  // ignore: do_not_use_environment -- compile-time proxy config seam
  static const _envProxySecure = bool.fromEnvironment(
    'fibs_proxy_secure',
    defaultValue: true,
  );
  // ignore: do_not_use_environment -- compile-time proxy config seam
  static const _envProxyPath = String.fromEnvironment(
    'fibs_proxy_path',
    defaultValue: '/fibs',
  );

  // the FIBS lobby roster (who-list + bot-only invite/watch queries)
  final lobby = FibsLobby();
  NotifierList<WhoInfo> get whoInfos => lobby.entries;
  final messages = NotifierList<FibsMessage>();
  final AppAnalytics analytics;
  final Duration _loginTimeout;
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

  // Called to auto-reconnect after an UNEXPECTED drop (not a logout). Wired by
  // the app to re-login with remembered credentials; must throw if it can't
  // (e.g. no remembered password), so we fall back to the login screen instead
  // of claiming to reconnect. FibsState owns the loop guard (_reconnectUsed),
  // not this hook.
  Future<void> Function()? onReconnect;

  // One auto-reconnect per successfully-established session: set when we spend
  // it on a drop, cleared when a fresh login reaches CLIP_WELCOME. A reconnect
  // that itself drops before welcome therefore does NOT loop -- it lands the
  // user on the login screen.
  bool _reconnectUsed = false;
  bool _lobbyReadyTracked = false;
  bool _doublePromptToggleSent = false;
  bool _moreboardsToggleSent = false;
  final _resume = FibsResumeCoordinator();
  var _cookieCount = 0;
  FibsCookie? _lastCookie;
  var _whoInfoCookieCount = 0;
  var _whoListComplete = false;

  // the game model for rendering, derived from the session (null when not in a
  // game); the raw FIBS board snapshot behind it (turn, dice, names, canMove)
  GammonState? get gameState => _session.gameState;
  FibsBoard? get board => _session.board;

  bool get doubleOffered => _session.doubleOffered;
  List<SavedMatchInfo> get savedMatchInfos {
    final matchesByOpponent = <String, SavedMatchInfo>{
      for (final match in _session.savedMatches.values)
        FibsResumeCoordinator.key(match.opponent): match,
    };
    final currentUser = user;
    if (currentUser != null) {
      final currentLower = currentUser.toLowerCase();
      for (final who in whoInfos) {
        if (who.opponent.toLowerCase() != currentLower) continue;
        final key = FibsResumeCoordinator.key(who.user);
        final existing = matchesByOpponent[key];
        matchesByOpponent[key] = SavedMatchInfo(
          opponent: existing?.opponent ?? who.user,
          score1: existing?.score1,
          score2: existing?.score2,
          matchLength: existing?.matchLength,
          availability: SavedMatchAvailability.ready,
        );
      }
    }
    final matches = matchesByOpponent.values.toList(growable: false);
    matches.sort(_compareSavedMatches);
    return matches;
  }

  List<String> get savedMatches =>
      savedMatchInfos.map((match) => match.opponent).toList(growable: false);
  String? get resumeRequestFrom => _session.resumeRequestFrom;
  bool get mustJoin => _session.mustJoin;

  List<SavedMatchDisplay> get savedMatchDisplays => [
    for (final match in savedMatchInfos)
      savedMatchDisplayFor(
        match: match,
        currentUser: user,
        resumePending: resumePendingFor(match.opponent),
        resumeRequested:
            resumeRequestFrom?.toLowerCase() == match.opponent.toLowerCase(),
        resumeDelay: resumeDelayFor(match.opponent),
        who: _whoFor(match.opponent),
      ),
  ];

  ResumeDelayInfo? resumeDelayFor(String opponent) =>
      _resume.delayFor(opponent);

  bool resumePendingFor(String opponent) => _resume.pendingFor(opponent);

  WhoInfo? _whoFor(String opponent) {
    final lower = opponent.toLowerCase();
    for (final who in whoInfos) {
      if (who.user.toLowerCase() == lower) return who;
    }
    return null;
  }

  static int _compareSavedMatches(SavedMatchInfo a, SavedMatchInfo b) {
    final status = _savedMatchRank(a).compareTo(_savedMatchRank(b));
    if (status != 0) return status;
    final folded = a.opponent.toLowerCase().compareTo(b.opponent.toLowerCase());
    if (folded != 0) return folded;
    return a.opponent.compareTo(b.opponent);
  }

  static int _savedMatchRank(SavedMatchInfo match) =>
      switch (match.availability) {
        SavedMatchAvailability.ready => 0,
        SavedMatchAvailability.online => 1,
        SavedMatchAvailability.unknown => 2,
        SavedMatchAvailability.offline => 3,
      };

  String? get user => _session.user;
  bool get connected => user != null && (_conn?.connected ?? false);

  WhoInfo? get currentUserInfo {
    final current = user;
    if (current == null) return null;
    final currentLower = current.toLowerCase();
    for (final who in whoInfos) {
      if (who.user.toLowerCase() == currentLower) return who;
    }
    return null;
  }

  // --- play state (only meaningful when we are a player, not just watching) --

  GammonPlayer? get myColor => _session.myColor;
  bool get isMyTurn => _session.isMyTurn;

  // The dice the UI should display/play -- the board's dice, or the ones we
  // just rolled when FIBS delivered them via a "You roll x and y" message
  // without a fresh board carrying them.
  List<int> get activeDice => _session.effectiveDice;

  bool get canMoveNow => _session.canMoveNow;
  bool get canRoll => _session.canRoll;
  bool get canOfferDouble => _session.canOfferDouble;

  // The current game has finished (FIBS announced a result, or 15 borne off).
  bool get isGameOver => _session.isGameOver;
  String? get gameResultMessage => _session.resultMessage;

  int get cookieCount => _cookieCount;
  String? get lastCookie => _lastCookie?.name;
  int get whoInfoCookieCount => _whoInfoCookieCount;
  bool get whoListComplete => _whoListComplete;
  bool get lastCommandRejected =>
      _lastCookie != null && _commandRejectedCookies.contains(_lastCookie);

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
    _cookieCount += 1;
    _lastCookie = cm.cookie;
    if (cm.cookie == FibsCookie.CLIP_WHO_INFO) _whoInfoCookieCount += 1;
    if (cm.cookie == FibsCookie.CLIP_WHO_END) _whoListComplete = true;
    // log only the cookie TYPE -- the crumbs/raw carry other users' PII
    // (who-list emails, chat text). Full content goes only to the opt-in,
    // local trace via cookieObserver (e.g. the live e2e), never the app log.
    _log.finer(cm.cookie.name);
    // Dispatch by cookie; any other gameplay/lobby chatter is ignored (no
    // handler) rather than crashing the stream.
    _handlers[cm.cookie]?.call(cm);
    cookieObserver?.call(cm);
  }

  // Cookie -> handler. Lobby and chat are growing collections with their own
  // notifiers, so they stay here; every game/turn cookie folds into the pure
  // session reducer via _applyCookie (one place, one source of truth).
  late final Map<FibsCookie, void Function(CookieMessage)> _handlers = {
    FibsCookie.CLIP_WHO_INFO: _onWhoInfo,
    FibsCookie.CLIP_WHO_END: (_) => _trackLobbyReady(),
    FibsCookie.CLIP_OWN_INFO: _onOwnInfo,
    FibsCookie.CLIP_LOGOUT: _onWhoLogout,
    FibsCookie.CLIP_KIBITZES: _onChatMessage,
    FibsCookie.CLIP_MESSAGE: _onChatMessage,
    FibsCookie.CLIP_SAYS: _onChatMessage,
    FibsCookie.CLIP_SHOUTS: _onChatMessage,
    FibsCookie.CLIP_WHISPERS: _onChatMessage,
    FibsCookie.FIBS_YouRoll: _applyCookie,
    FibsCookie.FIBS_PlayerRolls: _applyCookie,
    FibsCookie.FIBS_Turn: _onTurnText,
    FibsCookie.FIBS_PleaseMove: _onMovePrompt,
    FibsCookie.FIBS_YourTurnToMove: _onMovePrompt,
    FibsCookie.FIBS_PlayerMoves: _onBoardRefreshText,
    FibsCookie.FIBS_PlayerCantMove: _onCantMoveText,
    FibsCookie.FIBS_CantMove: _onCantMoveText,
    FibsCookie.FIBS_RollOrDouble: _applyCookie,
    FibsCookie.FIBS_Board: _onBoard,
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
    // FIBS accepted our login while another session was already connected under
    // this account (it takes over the connection); let the user know why the
    // other session just dropped.
    FibsCookie.FIBS_WARNINGAlreadyLoggedIn: (_) => _notice(
      'You were already logged in elsewhere; this session took over.',
    ),
    FibsCookie.FIBS_AcceptRejectDouble: _applyCookie,
    FibsCookie.FIBS_SavedMatch: _applyCookie,
    FibsCookie.FIBS_SavedMatchPlaying: _applyCookie,
    FibsCookie.FIBS_SavedMatchReady: _applyCookie,
    FibsCookie.FIBS_NoSavedGames: _applyCookie,
    FibsCookie.FIBS_ResumeMatchRequest: _onResumeMatchRequest,
    FibsCookie.FIBS_TypeJoin: _onTypeJoin,
    // Between games inside the same live match, FIBS asks for a bare `join`.
    // Continue the match automatically; this is not a saved-match resume.
    FibsCookie.FIBS_JoinNextGame: _applyAndAutoJoin,
    FibsCookie.FIBS_ResumeMatchAck0: _onResumeMatchAccepted,
    FibsCookie.FIBS_ResumeMatchAck5: _onResumeMatchAccepted,
    FibsCookie.FIBS_OpponentLogsOut: _onGameSavedByOpponent,
    FibsCookie.FIBS_OpponentLeftGame: _onGameSavedByOpponent,
    FibsCookie.FIBS_BadMove: _onCommandRejected,
    FibsCookie.FIBS_CantMoveFirstMove: _onCommandRejected,
    FibsCookie.FIBS_MustComeIn: _onCommandRejected,
    FibsCookie.FIBS_MustMove: _onCommandRejected,
    FibsCookie.FIBS_NoSavedMatch: _onSystemMessage,
    FibsCookie.FIBS_WARNINGSavedMatch: (_) {},
    FibsCookie.FIBS_NoOne: _onSystemMessage,
    FibsCookie.FIBS_NoUser: _onSystemMessage,
    FibsCookie.FIBS_PlayerRefusingGames: _onSystemMessage,
    FibsCookie.FIBS_AlreadyPlaying: _onAlreadyPlaying,
    FibsCookie.FIBS_DidntInvite: _onSystemMessage,
    FibsCookie.FIBS_DontKnowUser: _onSystemMessage,
    FibsCookie.FIBS_NotYourTurnToMove: _onSystemMessage,
    FibsCookie.FIBS_NotYourTurnToRoll: _onSystemMessage,
    FibsCookie.FIBS_NotPlaying: _onSystemMessage,
    FibsCookie.FIBS_NotWatchingPlaying: _onSystemMessage,
    FibsCookie.FIBS_UnknownCommand: _onSystemMessage,
  };

  // fold an inbound game/turn cookie into the session and republish
  void _applyCookie(CookieMessage cm) {
    final wasInGame = _session.board != null;
    final wasGameOver = _session.isGameOver;
    _resume.clearDelayForCookie(cm);
    _resume.clearAttemptForCookie(cm);
    _session = _session.reduce(cm);
    _trackSessionTransition(wasInGame: wasInGame, wasGameOver: wasGameOver);
    notifyListeners();
  }

  void _onBoard(CookieMessage cm) {
    final board = _session.board == null
        ? FibsBoard.fromCrumbs(cm.crumbs!)
        : null;
    final decision = _resume.decideBoard(
      opponent: board?.opponentNameFor(_session.user),
      hasSessionBoard: _session.board != null,
    );
    if (decision.action == FibsResumeBoardAction.park) {
      _parkSavedMatchInLobby(
        decision.opponent,
        refreshSavedGames: decision.refreshSavedGames,
      );
      return;
    }
    if (decision.action == FibsResumeBoardAction.ignore) {
      return;
    }
    _applyCookie(cm);
  }

  // Reduce a next-game prompt and immediately send `join` so an active match
  // continues. Saved-match resume prompts are handled separately so login does
  // not auto-enter an unfinished game.
  void _applyAndAutoJoin(CookieMessage cm) {
    final wasInGame = _session.board != null;
    final wasGameOver = _session.isGameOver;
    _session = _session.reduce(cm);
    _trackSessionTransition(wasInGame: wasInGame, wasGameOver: wasGameOver);
    if (_session.mustJoin) {
      joinGame(); // sends `join` and clears the prompt
    }
    notifyListeners();
  }

  void _onResumeMatchAccepted(CookieMessage cm) {
    final wasInGame = _session.board != null;
    final wasGameOver = _session.isGameOver;
    final opponent = cm.crumbOrNull(FibsCrumbKeys.opponent);
    final decision = _resume.acceptResumeAcknowledgement(opponent);
    if (decision.action == FibsResumeAckAction.park) {
      _parkSavedMatchInLobby(
        decision.opponent,
        refreshSavedGames: decision.refreshSavedGames,
      );
      return;
    }
    final saved = opponent == null ? null : _session.savedMatches[opponent];
    _session = _session.reduce(cm);
    if (_session.board == null && opponent != null) {
      _session = _session.copyWith(
        savedMatches: {
          ..._session.savedMatches,
          opponent:
              saved ??
              SavedMatchInfo(
                opponent: opponent,
                availability: SavedMatchAvailability.ready,
              ),
        },
      );
    }
    _trackSessionTransition(wasInGame: wasInGame, wasGameOver: wasGameOver);
    notifyListeners();
    _conn?.send('board');
  }

  void _onResumeMatchRequest(CookieMessage cm) {
    final wasInGame = _session.board != null;
    final wasGameOver = _session.isGameOver;
    _resume.clearDelayForCookie(cm);
    final opponent = cm.crumbOrNull(FibsCrumbKeys.name);
    final joining = _resume.shouldJoinPromptFrom(opponent);
    _session = _session.reduce(cm);
    if (joining) {
      _conn?.send('join $opponent');
      _session = _session.joined();
    }
    _trackSessionTransition(wasInGame: wasInGame, wasGameOver: wasGameOver);
    notifyListeners();
  }

  void _onTypeJoin(CookieMessage cm) {
    final wasInGame = _session.board != null;
    final wasGameOver = _session.isGameOver;
    final opponent = cm.crumbOrNull(FibsCrumbKeys.opponent);
    final joining = _resume.shouldJoinPromptFrom(opponent);
    _session = _session.reduce(cm);
    if (joining) {
      _conn?.send('join $opponent');
      _session = _session.joined();
    }
    _trackSessionTransition(wasInGame: wasInGame, wasGameOver: wasGameOver);
    notifyListeners();
  }

  void _onAlreadyPlaying(CookieMessage cm) => _onSystemMessage(cm);

  void _publish() => notifyListeners();

  void _onTurnText(CookieMessage cm) {
    _applyCookie(cm);
    if (_session.board != null &&
        !canRoll &&
        !canMoveNow &&
        !_session.isGameOver) {
      _conn?.send('board');
    }
  }

  void _onMovePrompt(CookieMessage cm) {
    _applyCookie(cm);
    if (!canMoveNow) _conn?.send('board');
  }

  void _onBoardRefreshText(CookieMessage cm) {
    if (_session.board != null) _conn?.send('board');
  }

  void _onCantMoveText(CookieMessage cm) {
    _applyCookie(cm);
    if (_session.board != null) _conn?.send('board');
  }

  void _parkSavedMatchInLobby(String? opponent, {bool? refreshSavedGames}) {
    _session = _session.outOfGame(savedOpponent: opponent);
    if (refreshSavedGames ?? _resume.markParked(opponent)) {
      _conn?.send('leave');
      _conn?.send('show savedgames');
    }
    notifyListeners();
  }

  void _onWhoInfo(CookieMessage cm) {
    lobby.upsert(WhoInfo.from(cm));
    notifyListeners();
  }

  void _onWhoLogout(CookieMessage cm) {
    lobby.remove(cm.crumb(FibsCrumbKeys.name));
    notifyListeners();
  }

  void _onOwnInfo(CookieMessage cm) {
    final doublePrompt = cm.crumbOrNull('double');
    if (doublePrompt == '1') {
      _doublePromptToggleSent = false;
    } else if (doublePrompt == '0' && !_doublePromptToggleSent) {
      _doublePromptToggleSent = true;
      _conn?.send('toggle double');
    }

    final moreboards = cm.crumbOrNull('moreboards');
    if (moreboards == '1') {
      _moreboardsToggleSent = false;
    } else if (moreboards == '0' && !_moreboardsToggleSent) {
      _moreboardsToggleSent = true;
      _conn?.send('toggle moreboards');
    }
  }

  void _trackLobbyReady() {
    if (_lobbyReadyTracked) return;
    _lobbyReadyTracked = true;
    analytics.track(
      'app_fibs_lobby_ready',
      screen: 'fibs_lobby',
      whoInfoCount: whoInfos.length,
      availableBotCount: lobby.availableBots.length,
      watchableBotCount: lobby.watchableBots.length,
      savedMatchCount: savedMatches.length,
      messageCount: messages.length,
    );
  }

  void _trackSessionTransition({
    required bool wasInGame,
    required bool wasGameOver,
  }) {
    final inGame = _session.board != null;
    if (!wasInGame && inGame) {
      final watching = _session.myColor == null;
      analytics.track(
        'app_fibs_game_start',
        screen: watching ? 'fibs_watch' : 'fibs_play',
        mode: watching ? 'watching' : 'playing',
      );
    }
    if (!wasGameOver && _session.isGameOver) {
      final won = didIWin;
      var result = 'unknown';
      if (won != null) result = won ? 'win' : 'loss';
      analytics.track('app_fibs_game_end', screen: 'fibs_play', result: result);
    }
  }

  void _onChatMessage(CookieMessage cm) {
    final from =
        cm.crumbOrNull(FibsCrumbKeys.name) ??
        cm.crumbOrNull(FibsCrumbKeys.from) ??
        'FIBS';
    final message = cm.crumb(FibsCrumbKeys.message);
    final resumeDelay = FibsResumeCoordinator.parseDelay(from, message);
    if (resumeDelay != null) {
      _resume.recordDelay(resumeDelay);
    }
    messages.add(FibsMessage(cm.cookie, from, message));
    if (resumeDelay != null) notifyListeners();
  }

  void _onSystemMessage(CookieMessage cm) {
    final cleared = _resume.clearRejected(cm.cookie);
    messages.add(FibsMessage(cm.cookie, 'FIBS', _displayMessage(cm)));
    if (cleared) notifyListeners();
  }

  void _onCommandRejected(CookieMessage cm) {
    _session = _session.commandRejected();
    _onSystemMessage(cm);
    notifyListeners();
  }

  void _onGameSavedByOpponent(CookieMessage cm) {
    final opponent =
        cm.crumbOrNull(FibsCrumbKeys.opponent) ??
        _session.board?.opponentNameFor(_session.user);
    _resume.suppressBoards();
    _session = _session.outOfGame(savedOpponent: opponent);
    _conn?.send('show savedgames');
    _onSystemMessage(cm);
    notifyListeners();
  }

  String _displayMessage(CookieMessage cm) {
    final text =
        cm.crumbOrNull(FibsCrumbKeys.message) ??
        cm.crumbOrNull('raw') ??
        cm.raw;
    return text.replaceFirst(RegExp(r'^\*\*\s*'), '');
  }

  bool get loggedIn => connected;

  // One-shot autologin guard: the login view attempts a remembered-credentials
  // autologin at most once per session. Without this, a connection that drops
  // right after login (e.g. FIBS kicking a duplicate login) recreates the login
  // view, which re-fires autologin, which reconnects and gets dropped again --
  // an infinite login<->lobby flash. An explicit logout keeps it spent for this
  // app session so remembered or baked-in credentials do not sign back in
  // immediately.
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
    analytics.track('app_fibs_login_attempt', screen: 'fibs_login');

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
        .timeout(_loginTimeout, onTimeout: () => FibsCookie.FIBS_Timeout);
    if (cookie != FibsCookie.CLIP_WELCOME) {
      await _sub?.cancel(); // don't leave the failed session's listener live
      _sub = null;
      await conn.close();
      analytics.track(
        'app_fibs_login_failed',
        screen: 'fibs_login',
        result: cookie == FibsCookie.FIBS_Timeout ? 'timeout' : 'rejected',
      );
      throw Exception(
        cookie == FibsCookie.FIBS_Timeout
            ? 'unable to connect; check your internet connection'
            : 'invalid user name and password',
      );
    }

    _session = _session.loggedInAs(user);
    _resume.startLoginDiscovery();
    _reconnectUsed = false; // a live session re-arms one auto-reconnect
    _lobbyReadyTracked = false;
    _doublePromptToggleSent = false;
    _moreboardsToggleSent = false;
    analytics.track('app_fibs_login_success', screen: 'fibs_lobby');
    // raw board frames are required for parsing; moreboards is toggled on from
    // CLIP_OWN_INFO below so FIBS sends a board after every roll/move
    _conn?.send('set boardstyle 3');
    // Explicitly request the who-list. FIBS pushes it automatically on a fresh
    // login, but not reliably on a quick reconnect -- asking for it makes the
    // bot list populate every time instead of sometimes hanging on "waiting for
    // the who-list".
    _conn?.send('who');
    // Ask FIBS for our unfinished saved matches. FIBS does NOT volunteer the
    // listing on login, so the lobby requests it before offering resume.
    _conn?.send('show savedgames');
    notifyListeners();
  }

  Future<void> createAccount({
    required String user,
    required String pass,
  }) async {
    assert(!loggedIn);
    analytics.track('app_fibs_account_create_attempt', screen: 'fibs_login');

    await _sub?.cancel();
    _sub = null;
    _expectClose = true;
    final conn = _makeTransport();
    _conn = conn;
    try {
      await conn.createAccount(user, pass).timeout(const Duration(seconds: 10));
      analytics.track('app_fibs_account_create_success', screen: 'fibs_login');
    } on Object {
      analytics.track('app_fibs_account_create_failed', screen: 'fibs_login');
      rethrow;
    } finally {
      await conn.close();
      if (identical(_conn, conn)) _conn = null;
      _expectClose = false;
    }
  }

  Future<void> logout() async {
    final conn = _conn;
    if (conn?.connected ?? false) conn?.send('bye');
    // an explicit logout means "don't auto-reconnect": let the app forget the
    // remembered password so the next launch shows the login screen instead of
    // signing back in. (Closing the tab is a different thing -- it keeps
    // remember -- so this hook fires only here, never on tab-close/drop.)
    //
    // Guard the hook: a secure-storage failure (locked keychain, missing
    // libsecret, web-crypto hiccup) must NOT abort teardown and orphan the
    // socket -- tearing the connection down is the more important half.
    _expectClose = true; // a deliberate close: the ensuing onDone stays silent
    final whoInfoCount = whoInfos.length;
    final availableBotCount = lobby.availableBots.length;
    final watchableBotCount = lobby.watchableBots.length;
    final savedMatchCount = savedMatches.length;
    final messageCount = messages.length;
    if (identical(_conn, conn)) _conn = null;
    final sub = _sub;
    _sub = null;
    _autoLoginTried = true; // stay logged out until the user acts or relaunches
    _reset();
    try {
      await onLogout?.call();
    } on Object catch (ex, st) {
      _log.warning('logout hook failed; tearing down anyway', ex, st);
    }
    try {
      final cancel = sub?.cancel();
      if (cancel != null) await cancel.timeout(const Duration(seconds: 2));
    } on Object catch (ex, st) {
      _log.warning('logout subscription cancel did not complete', ex, st);
    }
    try {
      final close = conn?.close();
      if (close != null) await close.timeout(const Duration(seconds: 2));
    } on Object catch (ex, st) {
      _log.warning('logout transport close did not complete', ex, st);
    }
    analytics.track(
      'app_fibs_logout',
      screen: 'fibs_login',
      whoInfoCount: whoInfoCount,
      availableBotCount: availableBotCount,
      watchableBotCount: watchableBotCount,
      savedMatchCount: savedMatchCount,
      messageCount: messageCount,
    );
  }

  // The connection closed. If WE didn't ask for it (logout), stay silent;
  // otherwise handle the unexpected drop.
  void _onStreamDone() => _onUnexpectedClose('Connection to FIBS lost.');

  // A mid-session transport failure: log it, then handle it as an unexpected
  // close rather than letting it escape as an unhandled async error.
  void _onStreamError(Object error, StackTrace stackTrace) {
    _log.warning('FIBS stream error', error, stackTrace);
    _onUnexpectedClose('FIBS connection error.');
  }

  // Shared close handler. A deliberate logout (_expectClose) is silent. An
  // unexpected drop resets, then either spends our one auto-reconnect (if a
  // reconnect hook is wired and unspent) or tells the user to log in again.
  void _onUnexpectedClose(String what) {
    final expected = _expectClose;
    if (!expected) {
      analytics.track(
        'app_fibs_connection_lost',
        screen: _session.board == null ? 'fibs_lobby' : 'fibs_play',
        result: what.startsWith('FIBS') ? 'error' : 'closed',
        whoInfoCount: whoInfos.length,
        availableBotCount: lobby.availableBots.length,
        watchableBotCount: lobby.watchableBots.length,
        savedMatchCount: savedMatches.length,
        messageCount: messages.length,
      );
    }
    _reset();
    if (expected) return;
    if (onReconnect != null && !_reconnectUsed) {
      _reconnectUsed = true;
      analytics.track('app_fibs_reconnect_attempt', screen: 'fibs_login');
      _notice('$what Reconnecting...');
      unawaited(_attemptReconnect());
    } else {
      _notice('$what Please log in again.');
    }
  }

  Future<void> _attemptReconnect() async {
    try {
      await onReconnect!.call();
    } on Object catch (ex, st) {
      // No remembered creds, or the reconnect login failed: land on the login
      // screen. _reconnectUsed stays set, so a drop of that attempt won't loop.
      _log.warning('auto-reconnect failed', ex, st);
      analytics.track('app_fibs_reconnect_failed', screen: 'fibs_login');
      _notice('Reconnect failed. Please log in again.');
    }
  }

  // Post a notice AFTER _reset (which clears messages) so the user sees why the
  // session ended. Shown by FibsPage's message SnackBar.
  void _notice(String text) =>
      messages.add(FibsMessage(FibsCookie.FIBS_Unknown, 'FIBS', text));

  void _reset() {
    lobby.clear();
    messages.clear();
    _session = const FibsSession();
    _lobbyReadyTracked = false;
    _doublePromptToggleSent = false;
    _moreboardsToggleSent = false;
    _resume.reset();
    _cookieCount = 0;
    _lastCookie = null;
    _whoInfoCookieCount = 0;
    _whoListComplete = false;
    notifyListeners();
  }

  void send(String cmd) => _conn?.send(cmd);
}
