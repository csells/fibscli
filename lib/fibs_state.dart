import 'dart:async';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'analytics.dart';
import 'bot_policy.dart';
import 'fibs_analytics.dart';
import 'fibs_board.dart';
import 'fibs_connection_lifecycle.dart';
import 'fibs_connection_policy.dart';
import 'fibs_crumb_keys.dart';
import 'fibs_diagnostics.dart';
import 'fibs_lobby.dart';
import 'fibs_protocol.dart';
import 'fibs_resume_coordinator.dart';
import 'fibs_saved_match_display.dart';
import 'fibs_session.dart';
import 'fibs_session_analytics.dart';
import 'fibs_transport.dart';
import 'model.dart';
import 'tinystate.dart';

export 'fibs_lobby.dart' show FibsLobby, WhoInfo;
export 'fibs_resume_coordinator.dart' show ResumeDelayInfo;
export 'fibs_saved_match_display.dart'
    show SavedMatchDisplay, SavedMatchDisplayState;
export 'fibs_session.dart' show SavedMatchAvailability, SavedMatchInfo;

part 'fibs_state_actions.dart';

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
       _connection = FibsConnectionLifecycle(
         makeTransport: () => FibsConnectionTransport(
           FibsConnection(
             proxy ?? _envProxyHost,
             port ?? _envProxyPort,
             secure: secure ?? _envProxySecure,
             path: path ?? _envProxyPath,
           ),
         ),
         loginTimeout: loginTimeout ?? _defaultLoginTimeout,
       );

  // Inject a transport (e.g. a fake) to drive the state without a live server.
  FibsState.withTransport(
    FibsTransport transport, {
    AppAnalytics? analytics,
    Duration? loginTimeout,
  }) : analytics = analytics ?? AppAnalytics.disabled(),
       _connection = FibsConnectionLifecycle(
         makeTransport: () => transport,
         loginTimeout: loginTimeout ?? _defaultLoginTimeout,
       );

  // Inject a transport FACTORY -- a fresh transport per login() -- so tests can
  // exercise reconnect / re-login with production-like (single-subscription,
  // real-close) transport semantics, which a single reused fake would hide.
  FibsState.withTransportFactory(
    FibsTransport Function() makeTransport, {
    AppAnalytics? analytics,
    Duration? loginTimeout,
  }) : analytics = analytics ?? AppAnalytics.disabled(),
       _connection = FibsConnectionLifecycle(
         makeTransport: makeTransport,
         loginTimeout: loginTimeout ?? _defaultLoginTimeout,
       );

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
  final FibsConnectionLifecycle _connection;

  FibsAnalyticsCounts get _analyticsCounts => FibsAnalyticsCounts(
    whoInfoCount: whoInfos.length,
    availableBotCount: lobby.availableBots.length,
    watchableBotCount: lobby.watchableBots.length,
    savedMatchCount: savedMatches.length,
    messageCount: messages.length,
  );

  // The immutable protocol state machine. It owns game/turn state and saved-match
  // resume state; this ChangeNotifier shell owns transport, lobby, chat, and
  // analytics.
  var _protocol = const FibsProtocolState();

  FibsSession get _session => _protocol.session;
  FibsResumeCoordinator get _resume => _protocol.resume;

  // Called on EXPLICIT logout only (not tab-close or a dropped connection), so
  // the app can run end-of-session cleanup (e.g. forgetting a remembered
  // password) without FibsState having to know about credentials. Injected by
  // the app in bootstrap; null in tests that don't care.
  Future<void> Function()? onLogout;

  // Called to auto-reconnect after an UNEXPECTED drop (not a logout). Wired by
  // the app to re-login with remembered credentials; must throw if it can't
  // (e.g. no remembered password), so we fall back to the login screen instead
  // of claiming to reconnect. The connection policy owns the one-shot guard.
  Future<void> Function()? onReconnect;

  // One auto-reconnect per successfully-established session: set when we spend
  // it on a drop, cleared when a fresh login reaches CLIP_WELCOME. A reconnect
  // that itself drops before welcome therefore does NOT loop -- it lands the
  // user on the login screen.
  bool _lobbyReadyTracked = false;
  var _connectionPolicy = const FibsConnectionPolicy();
  var _diagnostics = const FibsDiagnostics();

  // the game model for rendering, derived from the session (null when not in a
  // game); the raw FIBS board snapshot behind it (turn, dice, names, canMove)
  GammonState? get gameState => _session.gameState;
  FibsBoard? get board => _session.board;

  bool get doubleOffered => _session.doubleOffered;
  List<SavedMatchInfo> get savedMatchInfos => projectSavedMatchInfos(
    savedMatches: _session.savedMatches.values,
    whoInfos: whoInfos,
    currentUser: user,
  );

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

  String? get user => _session.user;
  bool get connected => user != null && _connection.connected;

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

  int get cookieCount => _diagnostics.cookieCount;
  String? get lastCookie => _diagnostics.lastCookie?.name;
  int get protocolSignalCount => _diagnostics.protocolSignalCount;
  Set<FibsProtocolSignal> get lastProtocolSignals =>
      _diagnostics.lastProtocolSignals;
  int get protocolMatchResultCount => _diagnostics.protocolMatchResultCount;
  FibsProtocolMatchResult? get lastProtocolMatchResult =>
      _diagnostics.lastProtocolMatchResult;
  int get whoInfoCookieCount => _diagnostics.whoInfoCookieCount;
  bool get whoListComplete => _diagnostics.whoListComplete;
  bool get lastCommandRejected => _diagnostics.lastCommandRejected;

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
    _diagnostics = _diagnostics.recordCookie(cm);
    // log only the cookie TYPE -- the crumbs/raw carry other users' PII
    // (who-list emails, chat text). Full content goes only to the opt-in,
    // local trace via cookieObserver (e.g. the live e2e), never the app log.
    _log.finer(cm.cookie.name);
    final handler = _handlers[cm.cookie];
    if (handler == null) {
      _handleProtocolRoutedCookie(cm);
    } else {
      handler(cm);
    }
    cookieObserver?.call(cm);
  }

  // Cookie -> handler for lobby and UI-only events. Gameplay, resume, command,
  // and chat categories are routed through fibsProtocolRouteFor below.
  late final Map<FibsCookie, void Function(CookieMessage)> _handlers = {
    FibsCookie.CLIP_WHO_INFO: _onWhoInfo,
    FibsCookie.CLIP_WHO_END: (_) => _trackLobbyReady(),
    FibsCookie.CLIP_LOGOUT: _onWhoLogout,
    // FIBS accepted our login while another session was already connected under
    // this account (it takes over the connection); let the user know why the
    // other session just dropped.
    FibsCookie.FIBS_WARNINGAlreadyLoggedIn: (_) => _notice(
      'You were already logged in elsewhere; this session took over.',
    ),
  };

  void _handleProtocolRoutedCookie(CookieMessage cm) {
    switch (fibsProtocolRouteFor(cm.cookie)) {
      case FibsProtocolCookieRoute.ignore:
        break;
      case FibsProtocolCookieRoute.protocol:
        _receiveProtocol(cm);
    }
  }

  // fold an inbound protocol cookie into the session and republish
  void _receiveProtocol(CookieMessage cm) =>
      _applyProtocolTransition(_protocol.receive(cm));

  void _applyProtocolTransition(
    FibsProtocolTransition transition, {
    bool? trackSession,
    bool notify = true,
  }) {
    final previousSession = _session;
    _protocol = transition.state;
    _diagnostics = _diagnostics.recordTransition(transition);
    for (final message in transition.messages) {
      messages.add(FibsMessage(message.cookie, message.from, message.text));
    }
    transition.commands.forEach(_connection.send);
    final shouldTrackSession =
        trackSession ?? transition.trackSessionTransition;
    if (shouldTrackSession) {
      _trackSessionTransition(previousSession);
    }
    if (notify) notifyListeners();
  }

  void _onWhoInfo(CookieMessage cm) {
    lobby.upsert(WhoInfo.from(cm));
    notifyListeners();
  }

  void _onWhoLogout(CookieMessage cm) {
    lobby.remove(cm.crumb(FibsCrumbKeys.name));
    notifyListeners();
  }

  void _trackLobbyReady() {
    if (_lobbyReadyTracked) return;
    _lobbyReadyTracked = true;
    analytics.trackFibs(
      'app_fibs_lobby_ready',
      screen: 'fibs_lobby',
      counts: _analyticsCounts,
    );
    notifyListeners();
  }

  void _trackSessionTransition(FibsSession previousSession) {
    for (final event in fibsSessionAnalyticsEvents(
      before: previousSession,
      after: _session,
    )) {
      analytics.track(
        event.name,
        screen: event.screen,
        mode: event.mode,
        result: event.result,
      );
    }
  }

  bool get loggedIn => connected;

  // One-shot autologin guard: the login view attempts a remembered-credentials
  // autologin at most once per session. Without this, a connection that drops
  // right after login (e.g. FIBS kicking a duplicate login) recreates the login
  // view, which re-fires autologin, which reconnects and gets dropped again --
  // an infinite login<->lobby flash. An explicit logout keeps it spent for this
  // app session so remembered or baked-in credentials do not sign back in
  // immediately.
  bool get autoLoginTried => _connectionPolicy.autoLoginTried;

  // True while WE are deliberately closing the connection (logout), so the
  // resulting onDone/onError is silent. An unexpected drop (server kick, network
  // loss) surfaces a "connection lost" notice instead of silently dumping the
  // user back on the login screen.
  void markAutoLoginTried() {
    _connectionPolicy = _connectionPolicy.markAutoLoginTried();
  }

  Future<void> login({required String user, required String pass}) async {
    assert(!loggedIn);
    analytics.track('app_fibs_login_attempt', screen: 'fibs_login');

    _connectionPolicy = _connectionPolicy.beginLogin();
    final cookie = await _connection.login(
      user: user,
      pass: pass,
      onCookie: _streamItem,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
    if (cookie != FibsCookie.CLIP_WELCOME) {
      await _connection.closeCurrent();
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

    _applyProtocolTransition(
      _protocol.loggedInAs(user),
      trackSession: false,
      notify: false,
    );
    _connectionPolicy = _connectionPolicy.loginSucceeded();
    _lobbyReadyTracked = false;
    analytics.track('app_fibs_login_success', screen: 'fibs_lobby');
    notifyListeners();
  }

  Future<void> createAccount({
    required String user,
    required String pass,
  }) async {
    assert(!loggedIn);
    analytics.track('app_fibs_account_create_attempt', screen: 'fibs_login');

    _connectionPolicy = _connectionPolicy.beginExpectedClose();
    try {
      await _connection.createAccount(user: user, pass: pass);
      analytics.track('app_fibs_account_create_success', screen: 'fibs_login');
    } on Object {
      analytics.track('app_fibs_account_create_failed', screen: 'fibs_login');
      rethrow;
    } finally {
      _connectionPolicy = _connectionPolicy.finishExpectedCloseScope();
    }
  }

  Future<void> logout() async {
    if (_connection.connected) {
      _applyProtocolTransition(
        _protocol.courtesyDisconnect(),
        trackSession: false,
        notify: false,
      );
    }
    // an explicit logout means "don't auto-reconnect": let the app forget the
    // remembered password so the next launch shows the login screen instead of
    // signing back in. (Closing the tab is a different thing -- it keeps
    // remember -- so this hook fires only here, never on tab-close/drop.)
    //
    // Guard the hook: a secure-storage failure (locked keychain, missing
    // libsecret, web-crypto hiccup) must NOT abort teardown and orphan the
    // socket -- tearing the connection down is the more important half.
    _connectionPolicy = _connectionPolicy.beginExpectedClose(
      spendAutoLogin: true,
    );
    final analyticsCounts = _analyticsCounts;
    _reset();
    try {
      await onLogout?.call();
    } on Object catch (ex, st) {
      _log.warning('logout hook failed; tearing down anyway', ex, st);
    }
    await _connection.closeCurrent();
    analytics.trackFibs(
      'app_fibs_logout',
      screen: 'fibs_login',
      counts: analyticsCounts,
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

  // Shared close handler. Expected closes are silent. Unexpected drops reset,
  // then spend one reconnect attempt or ask the user to log in again.
  void _onUnexpectedClose(String what) {
    final decision = _connectionPolicy.handleConnectionClosed(
      canReconnect: onReconnect != null,
    );
    _connectionPolicy = decision.state;
    if (decision.action != FibsConnectionCloseAction.ignore) {
      analytics.trackFibs(
        'app_fibs_connection_lost',
        screen: _session.board == null ? 'fibs_lobby' : 'fibs_play',
        result: what.startsWith('FIBS') ? 'error' : 'closed',
        counts: _analyticsCounts,
      );
    }
    _reset();
    switch (decision.action) {
      case FibsConnectionCloseAction.ignore:
        return;
      case FibsConnectionCloseAction.reconnect:
        analytics.track('app_fibs_reconnect_attempt', screen: 'fibs_login');
        _notice('$what Reconnecting...');
        unawaited(_attemptReconnect());
      case FibsConnectionCloseAction.showLoginNotice:
        _notice('$what Please log in again.');
    }
  }

  Future<void> _attemptReconnect() async {
    try {
      await onReconnect!.call();
    } on Object catch (ex, st) {
      // No remembered creds, or the reconnect login failed: land on the login
      // screen. The policy keeps the reconnect spent, so that attempt cannot
      // loop after another drop.
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
    _protocol = const FibsProtocolState();
    _lobbyReadyTracked = false;
    _diagnostics = _diagnostics.reset();
    notifyListeners();
  }
}
