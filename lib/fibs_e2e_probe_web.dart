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
  final currentUser = fibs.user?.toLowerCase();
  for (final match in fibs.savedMatchInfos) {
    final opponent = match.opponent.toLowerCase();
    final pending = fibs.resumePendingFor(match.opponent);
    final delayed = fibs.resumeDelayFor(match.opponent) != null;
    final requested = fibs.resumeRequestFrom?.toLowerCase() == opponent;
    WhoInfo? who;
    for (final info in fibs.whoInfos) {
      if (info.user.toLowerCase() == opponent) {
        who = info;
        break;
      }
    }
    final playingCurrentUser =
        who != null &&
        currentUser != null &&
        who.opponent.toLowerCase() == currentUser;
    final canResume =
        !pending &&
        !delayed &&
        (requested ||
            playingCurrentUser ||
            (who != null && who.ready && who.opponent.isEmpty));
    if (canResume) {
      ready += 1;
    } else if (who != null && who.opponent.isNotEmpty && !playingCurrentUser) {
      busy += 1;
    } else {
      waiting += 1;
    }
  }
  return (ready: ready, busy: busy, waiting: waiting);
}
