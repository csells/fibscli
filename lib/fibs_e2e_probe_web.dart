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
}

Map<String, Object?> _snapshot(FibsState fibs) {
  final inGame = fibs.gameState != null;
  final playing = inGame && fibs.myColor != null;
  final watching = inGame && fibs.myColor == null;
  final activeDice = fibs.activeDice;
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
