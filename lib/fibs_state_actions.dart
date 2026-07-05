part of 'fibs_state.dart';

extension FibsStateActions on FibsState {
  void _applyPlayerIntent(FibsProtocolTransition Function() intent) {
    try {
      _applyProtocolTransition(intent(), trackSession: false);
    } on FibsProtocolError catch (error) {
      throw FibsStateError(error.message);
    }
  }

  // invite a bot to a match (precision-first: only bots). Default to a short
  // 3-point match so the doubling cube matters but games finish quickly.
  void invite(WhoInfo bot, {int matchLength = 3}) {
    assert(FibsState.isBot(bot), 'bots only');
    analytics.trackFibs(
      'app_fibs_invite',
      screen: 'fibs_lobby',
      mode: 'match_$matchLength',
      counts: _analyticsCounts,
      includeMessageCount: false,
    );
    _applyProtocolTransition(
      _protocol.inviteBot(bot.user, matchLength: matchLength),
      trackSession: false,
    );
  }

  // Resume an unfinished match with [opponent]. When the opponent explicitly
  // asks to resume, FIBS expects `join`; otherwise the normal saved-match
  // request is `invite`; FIBS reloads the saved game if the opponent accepts.
  void resumeSavedMatch(String opponent) {
    analytics.trackFibs(
      'app_fibs_resume_saved_match',
      screen: 'fibs_lobby',
      counts: _analyticsCounts,
      includeWhoInfoCount: false,
      includeAvailableBotCount: false,
      includeWatchableBotCount: false,
      includeMessageCount: false,
    );
    final currentUser = user;
    final activeWithMe =
        currentUser != null &&
        whoInfos.any(
          (who) =>
              who.user.toLowerCase() == opponent.toLowerCase() &&
              who.opponent.toLowerCase() == currentUser.toLowerCase(),
        );
    _applyProtocolTransition(
      activeWithMe
          ? _protocol.resumeActiveMatch(opponent)
          : _protocol.resumeSavedMatch(opponent),
      trackSession: false,
    );
  }

  // continue a resumed/next game when FIBS asks us to type 'join'
  void joinGame([String? opponent]) => _applyProtocolTransition(
    _protocol.joinGame(opponent),
    trackSession: false,
  );

  // Roll the dice. Throws if it isn't our turn to roll (so a mis-timed call is
  // a loud bug, not a silently dropped command).
  void roll() => _applyPlayerIntent(_protocol.startRoll);

  // Submit a WHOLE turn the player built locally on the shared board (the same
  // mechanic as the local game: make your moves, undo freely, then tap the dice
  // to commit). FIBS wants the complete turn in one command, so we send it all
  // at once -- a partial turn is what triggers "** You must give N moves". The
  // moves are in viewer pips (player one); an empty list is a dance (pass).
  void submitTurn(List<GammonMove> moves) =>
      _applyPlayerIntent(() => _protocol.submitTurn(moves));

  // Send a pre-built whole-turn `move ...` [command] and mark the turn
  // committed (canMoveNow off until the next board). This is pure transport:
  // the POLICY of WHICH turn to play (pubeval / an AI engine) lives in the
  // caller -- e.g. FibsBotPlayer -- so this connection/state machine stays free
  // of move selection. Throws if it isn't our turn to move.
  void commitTurnCommand(String command) =>
      _applyPlayerIntent(() => _protocol.commitTurnCommand(command));

  void offerDouble() => _applyPlayerIntent(_protocol.offerDouble);

  void acceptDouble() => _applyPlayerIntent(_protocol.acceptDouble);

  void rejectDouble() => _applyPlayerIntent(_protocol.rejectDouble);

  void refreshWhoList() => _applyProtocolTransition(
    _protocol.refreshWhoList(),
    trackSession: false,
    notify: false,
  );

  void inviteBotByName(String user, {int matchLength = 1}) =>
      _applyProtocolTransition(
        _protocol.inviteBotByName(user, matchLength: matchLength),
        trackSession: false,
      );

  void resign() => _applyProtocolTransition(
    _protocol.resignNormalLoss(),
    trackSession: false,
  );

  void courtesyDisconnect() => _applyProtocolTransition(
    _protocol.courtesyDisconnect(),
    trackSession: false,
    notify: false,
  );

  void leaveGame() {
    analytics.track('app_fibs_leave_game', screen: 'fibs_play');
    _applyProtocolTransition(_protocol.leaveGame(), trackSession: false);
  }

  // Dismiss a finished game and return to the lobby. The game is already over
  // server-side, so there's nothing to `leave` -- just clear the local board.
  void returnToLobby() =>
      _applyProtocolTransition(_protocol.returnToLobby(), trackSession: false);

  // free bot invite targets / watchable in-game bots (delegated to the lobby)
  List<WhoInfo> get availableBots => lobby.availableBots;
  List<WhoInfo> get watchableBots => lobby.watchableBots;

  void watch(WhoInfo who) {
    assert(FibsState.isBot(who), 'bots only');
    analytics.trackFibs(
      'app_fibs_watch',
      screen: 'fibs_lobby',
      counts: _analyticsCounts,
      includeSavedMatchCount: false,
      includeMessageCount: false,
    );
    _applyProtocolTransition(_protocol.watch(who.user), trackSession: false);
  }

  void stopWatching() {
    analytics.track('app_fibs_stop_watching', screen: 'fibs_watch');
    _applyProtocolTransition(_protocol.stopWatching(), trackSession: false);
  }
}
