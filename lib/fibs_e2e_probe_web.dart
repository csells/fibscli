import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'fibs_state.dart';

void installFibsE2eProbe(FibsState fibs) {
  // ignore: do_not_use_environment -- e2e-only compile-time test hook
  const enabled = bool.fromEnvironment('fibs_e2e_probe');
  if (!enabled) return;

  globalContext.setProperty(
    '__fibscliE2EState'.toJS,
    (() => _snapshot(fibs).jsify()).toJS,
  );
  globalContext.setProperty(
    '__fibscliE2EAction'.toJS,
    ((JSString action) => _runAction(fibs, action.toDart).jsify()).toJS,
  );
}

Map<String, Object?> _snapshot(FibsState fibs) {
  final inGame = fibs.gameState != null;
  final playing = inGame && fibs.myColor != null;
  final watching = inGame && fibs.myColor == null;
  final activeDice = fibs.activeDice;
  final savedResumeCounts = _savedResumeCounts(fibs);
  return {
    'loggedIn': fibs.loggedIn,
    'connected': fibs.connected,
    'autoLoginTried': fibs.autoLoginTried,
    'hasUser': fibs.user != null,
    'whoCount': fibs.whoInfos.length,
    'botCount': fibs.availableBots.length + fibs.watchableBots.length,
    'availableBotCount': fibs.availableBots.length,
    'watchableBotCount': fibs.watchableBots.length,
    'savedMatchCount': fibs.savedMatches.length,
    'savedMatchReadyCount': savedResumeCounts.ready,
    'savedMatchBusyCount': savedResumeCounts.busy,
    'savedMatchWaitingCount': savedResumeCounts.waiting,
    'inGame': inGame,
    'playing': playing,
    'watching': watching,
    'doubleOffered': fibs.doubleOffered,
    'isMyTurn': fibs.isMyTurn,
    'canRoll': fibs.canRoll,
    'canMoveNow': fibs.canMoveNow,
    'activeDice': activeDice,
    'isGameOver': fibs.isGameOver,
    'didIWin': fibs.didIWin,
    'messageCount': fibs.messages.length,
    'cookieCount': fibs.cookieCount,
    'lastCookie': fibs.lastCookie,
    'whoInfoCookieCount': fibs.whoInfoCookieCount,
    'whoListComplete': fibs.whoListComplete,
  };
}

({int ready, int busy, int waiting}) _savedResumeCounts(FibsState fibs) {
  var ready = 0;
  var busy = 0;
  var waiting = 0;
  for (final display in fibs.savedMatchDisplays) {
    switch (display.state) {
      case SavedMatchDisplayState.requested ||
          SavedMatchDisplayState.activeWithUser ||
          SavedMatchDisplayState.ready:
        ready += 1;
      case SavedMatchDisplayState.busy:
        busy += 1;
      case SavedMatchDisplayState.delayed ||
          SavedMatchDisplayState.pending ||
          SavedMatchDisplayState.checking ||
          SavedMatchDisplayState.unavailable ||
          SavedMatchDisplayState.saved:
        waiting += 1;
    }
  }
  return (ready: ready, busy: busy, waiting: waiting);
}

Map<String, Object?> _runAction(FibsState fibs, String action) {
  switch (action) {
    case 'leaveGame':
      if (fibs.gameState == null) return {'ok': false};
      fibs.leaveGame();
      return {'ok': true};
    case 'logout':
      if (!fibs.loggedIn) return {'ok': false};
      unawaited(fibs.logout());
      return {'ok': true};
    case 'resumeFirstReady':
      for (final display in fibs.savedMatchDisplays) {
        if (!display.canResume) continue;
        fibs.resumeSavedMatch(display.match.opponent);
        return {'ok': true, 'opponent': display.match.opponent};
      }
      return {'ok': false};
    default:
      throw UnsupportedError('unknown FIBS e2e action: $action');
  }
}
