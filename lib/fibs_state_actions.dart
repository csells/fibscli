part of 'fibs_state.dart';

extension FibsStateActions on FibsState {
  // invite a bot to a match (precision-first: only bots). Default to a short
  // 3-point match so the doubling cube matters but games finish quickly.
  void invite(WhoInfo bot, {int matchLength = 3}) {
    assert(FibsState.isBot(bot), 'bots only');
    _resume.allowBoardAdmission();
    analytics.track(
      'app_fibs_invite',
      screen: 'fibs_lobby',
      mode: 'match_$matchLength',
      whoInfoCount: whoInfos.length,
      availableBotCount: availableBots.length,
      watchableBotCount: watchableBots.length,
      savedMatchCount: savedMatches.length,
    );
    _conn?.send('invite ${bot.user} $matchLength');
  }

  // Resume an unfinished match with [opponent]. When the opponent explicitly
  // asks to resume, FIBS expects `join`; otherwise the normal saved-match
  // request is `invite`; FIBS reloads the saved game if the opponent accepts.
  void resumeSavedMatch(String opponent) {
    _resume.beginAttempt(opponent);
    analytics.track(
      'app_fibs_resume_saved_match',
      screen: 'fibs_lobby',
      savedMatchCount: savedMatches.length,
    );
    if (_shouldJoinSavedMatch(opponent)) {
      _conn?.send('join $opponent');
      _session = _session.joined();
    } else {
      _conn?.send('invite $opponent');
    }
    _publish();
  }

  // continue a resumed/next game when FIBS asks us to type 'join' (also accepts
  // an opponent's resume request tracked in [resumeRequestFrom])
  void joinGame([String? opponent]) {
    _resume.allowBoardAdmission();
    _conn?.send(opponent == null ? 'join' : 'join $opponent');
    _session = _session.joined();
    _publish();
  }

  bool _shouldJoinSavedMatch(String opponent) {
    final opponentLower = opponent.toLowerCase();
    if (resumeRequestFrom?.toLowerCase() == opponentLower) return true;
    return false;
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
    _publish();
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
    _publish();
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
    _publish();
  }

  void offerDouble() {
    if (!canOfferDouble) {
      throw FibsStateError(
        'offerDouble: can only double on our turn before '
        'rolling when FIBS allows it '
        '(isMyTurn=$isMyTurn dice=$activeDice canRoll=$canRoll)',
      );
    }
    _session = _session
        .committed(); // we've acted this turn; await the response
    _conn?.send('double');
    _publish();
  }

  void acceptDouble() {
    if (!doubleOffered) {
      throw FibsStateError('acceptDouble: no double has been offered');
    }
    _conn?.send('accept');
    _session = _session.doubleResolved();
    _publish();
  }

  void rejectDouble() {
    if (!doubleOffered) {
      throw FibsStateError('rejectDouble: no double has been offered');
    }
    _conn?.send('reject');
    _session = _session.doubleResolved();
    _publish();
  }

  void resign() => _conn?.send('resign n'); // resign a normal loss

  void leaveGame() {
    analytics.track('app_fibs_leave_game', screen: 'fibs_play');
    final opponent = _session.board?.opponentNameFor(_session.user);
    _resume.suppressBoards();
    _conn?.send('leave');
    _session = _session.outOfGame(savedOpponent: opponent);
    _conn?.send('show savedgames');
    _publish();
  }

  // Dismiss a finished game and return to the lobby. The game is already over
  // server-side, so there's nothing to `leave` -- just clear the local board.
  void returnToLobby() {
    _resume.suppressBoards();
    _session = _session.outOfGame();
    _publish();
  }

  // free bot invite targets / watchable in-game bots (delegated to the lobby)
  List<WhoInfo> get availableBots => lobby.availableBots;
  List<WhoInfo> get watchableBots => lobby.watchableBots;

  void watch(WhoInfo who) {
    assert(FibsState.isBot(who), 'bots only');
    _resume.allowBoardAdmission();
    analytics.track(
      'app_fibs_watch',
      screen: 'fibs_lobby',
      whoInfoCount: whoInfos.length,
      availableBotCount: availableBots.length,
      watchableBotCount: watchableBots.length,
    );
    _session = _session.outOfGame();
    _conn?.send('watch ${who.user}');
    _publish();
  }

  void stopWatching() {
    analytics.track('app_fibs_stop_watching', screen: 'fibs_watch');
    _resume.suppressBoards();
    _conn?.send('unwatch');
    _session = _session.outOfGame();
    _publish();
  }
}
