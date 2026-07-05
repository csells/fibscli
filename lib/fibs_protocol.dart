import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_board.dart';
import 'fibs_crumb_keys.dart';
import 'fibs_protocol_events.dart';
import 'fibs_protocol_intents.dart';
import 'fibs_protocol_settings.dart';
import 'fibs_resume_coordinator.dart';
import 'fibs_session.dart';
import 'model.dart';

export 'fibs_protocol_events.dart'
    show FibsProtocolMatchResult, FibsProtocolMessage;
export 'fibs_protocol_intents.dart' show FibsProtocolError;

enum FibsProtocolSignal { boardFrame, opponentRolled, commandRejected }

const _sessionCookieHandlers = {
  FibsCookie.FIBS_YouRoll,
  FibsCookie.FIBS_PlayerRolls,
  FibsCookie.FIBS_RollOrDouble,
  FibsCookie.FIBS_YouWinGame,
  FibsCookie.FIBS_PlayerWinsGame,
  FibsCookie.FIBS_YouWinMatch,
  FibsCookie.FIBS_PlayerWinsMatch,
  FibsCookie.FIBS_ResignYouWin,
  FibsCookie.FIBS_YouAcceptAndWin,
  FibsCookie.FIBS_AcceptWins,
  FibsCookie.FIBS_ResignWins,
  FibsCookie.FIBS_AcceptRejectDouble,
  FibsCookie.FIBS_SavedMatch,
  FibsCookie.FIBS_SavedMatchPlaying,
  FibsCookie.FIBS_SavedMatchReady,
  FibsCookie.FIBS_NoSavedGames,
};

const _movePromptCookieHandlers = {
  FibsCookie.FIBS_PleaseMove,
  FibsCookie.FIBS_YourTurnToMove,
};

const _cantMoveCookieHandlers = {
  FibsCookie.FIBS_PlayerCantMove,
  FibsCookie.FIBS_CantMove,
};

const _resumeAcceptedCookieHandlers = {
  FibsCookie.FIBS_ResumeMatchAck0,
  FibsCookie.FIBS_ResumeMatchAck5,
};

const _commandRejectedCookieHandlers = {
  FibsCookie.FIBS_BadMove,
  FibsCookie.FIBS_CantMoveFirstMove,
  FibsCookie.FIBS_MustComeIn,
  FibsCookie.FIBS_MustMove,
};

const _systemMessageCookieHandlers = {
  FibsCookie.FIBS_NoSavedMatch,
  FibsCookie.FIBS_NoOne,
  FibsCookie.FIBS_NoUser,
  FibsCookie.FIBS_PlayerRefusingGames,
  FibsCookie.FIBS_AlreadyPlaying,
  FibsCookie.FIBS_DidntInvite,
  FibsCookie.FIBS_DontKnowUser,
  FibsCookie.FIBS_NotYourTurnToMove,
  FibsCookie.FIBS_NotYourTurnToRoll,
  FibsCookie.FIBS_NotPlaying,
  FibsCookie.FIBS_NotWatchingPlaying,
  FibsCookie.FIBS_UnknownCommand,
};

const _chatCookieHandlers = {
  FibsCookie.CLIP_KIBITZES,
  FibsCookie.CLIP_MESSAGE,
  FibsCookie.CLIP_SAYS,
  FibsCookie.CLIP_SHOUTS,
  FibsCookie.CLIP_WHISPERS,
};

final Map<
  FibsCookie,
  FibsProtocolTransition Function(FibsProtocolState state, CookieMessage cm)
>
_protocolCookieHandlers = {
  FibsCookie.CLIP_OWN_INFO: (state, cm) => state.receiveOwnInfo(cm),
  for (final cookie in _sessionCookieHandlers)
    cookie: (state, cm) => state.applyCookie(cm),
  FibsCookie.FIBS_Turn: (state, cm) => state.receiveTurnText(cm),
  for (final cookie in _movePromptCookieHandlers)
    cookie: (state, cm) => state.receiveMovePrompt(cm),
  FibsCookie.FIBS_PlayerMoves: (state, cm) => state.receiveBoardRefreshText(cm),
  for (final cookie in _cantMoveCookieHandlers)
    cookie: (state, cm) => state.receiveCantMoveText(cm),
  FibsCookie.FIBS_Board: (state, cm) => state.receiveBoard(cm),
  FibsCookie.FIBS_WatchGameWins: (state, _) => state.watchedGameFinished(),
  FibsCookie.FIBS_OpponentLogsOut: (state, cm) =>
      state.receiveGameSavedByOpponent(cm),
  FibsCookie.FIBS_OpponentLeftGame: (state, cm) =>
      state.receiveGameSavedByOpponent(cm),
  FibsCookie.FIBS_ResumeMatchRequest: (state, cm) =>
      state.receiveResumeMatchRequest(cm),
  FibsCookie.FIBS_TypeJoin: (state, cm) => state.receiveTypeJoin(cm),
  FibsCookie.FIBS_JoinNextGame: (state, cm) => state.applyAndAutoJoin(cm),
  for (final cookie in _resumeAcceptedCookieHandlers)
    cookie: (state, cm) => state.receiveResumeMatchAccepted(cm),
  for (final cookie in _commandRejectedCookieHandlers)
    cookie: (state, cm) => state.commandRejected(cm),
  for (final cookie in _systemMessageCookieHandlers)
    cookie: (state, cm) => state.systemMessage(cm),
  for (final cookie in _chatCookieHandlers)
    cookie: (state, cm) => state.receiveChatMessage(cm),
};

@immutable
class FibsProtocolTransition {
  const FibsProtocolTransition({
    required this.state,
    this.commands = const [],
    this.signals = const {},
    this.messages = const [],
    this.matchResult,
    this.trackSessionTransition = true,
  });

  final FibsProtocolState state;
  final List<String> commands;
  final Set<FibsProtocolSignal> signals;
  final List<FibsProtocolMessage> messages;
  final FibsProtocolMatchResult? matchResult;
  final bool trackSessionTransition;

  FibsProtocolTransition withSignal(FibsProtocolSignal signal) =>
      FibsProtocolTransition(
        state: state,
        commands: commands,
        signals: {...signals, signal},
        messages: messages,
        matchResult: matchResult,
        trackSessionTransition: trackSessionTransition,
      );
}

@immutable
class FibsProtocolState {
  const FibsProtocolState({
    this.session = const FibsSession(),
    this.resume = const FibsResumeCoordinator(),
    this.settings = const FibsProtocolSettings(),
  });

  final FibsSession session;
  final FibsResumeCoordinator resume;
  final FibsProtocolSettings settings;

  FibsProtocolState copyWith({
    FibsSession? session,
    FibsResumeCoordinator? resume,
    FibsProtocolSettings? settings,
  }) => FibsProtocolState(
    session: session ?? this.session,
    resume: resume ?? this.resume,
    settings: settings ?? this.settings,
  );

  FibsProtocolTransition loggedInAs(String user) => FibsProtocolTransition(
    state: copyWith(
      session: session.loggedInAs(user),
      resume: resume.startLoginDiscovery(),
      settings: const FibsProtocolSettings(),
    ),
    commands: const ['set boardstyle 3', 'who', 'show savedgames'],
  );

  FibsProtocolTransition applyCookie(CookieMessage cm) =>
      _applyCookie(cm, resume);

  FibsProtocolTransition receive(CookieMessage cm) {
    final handler = _protocolCookieHandlers[cm.cookie];
    return handler == null
        ? FibsProtocolTransition(state: this, trackSessionTransition: false)
        : handler(this, cm);
  }

  FibsProtocolTransition receiveBoard(CookieMessage cm) {
    final board = session.board == null
        ? FibsBoard.fromCrumbs(cm.crumbs!)
        : null;
    final decision = resume.decideBoard(
      opponent: board?.opponentNameFor(session.user),
      hasSessionBoard: session.board != null,
    );
    return switch (decision.action) {
      FibsResumeBoardAction.admit => _copyWithResume(
        decision.resume,
      )._applyCookie(cm, decision.resume),
      FibsResumeBoardAction.ignore => FibsProtocolTransition(
        state: copyWith(resume: decision.resume),
      ),
      FibsResumeBoardAction.park => _parkSavedMatchInLobby(
        decision.opponent,
        resume: decision.resume,
        refreshSavedGames: decision.refreshSavedGames,
      ),
    };
  }

  FibsProtocolTransition receiveResumeMatchAccepted(CookieMessage cm) {
    final opponent = cm.crumbOrNull(FibsCrumbKeys.opponent);
    final decision = resume.acceptResumeAcknowledgement(opponent);
    if (decision.action == FibsResumeAckAction.park) {
      return _parkSavedMatchInLobby(
        decision.opponent,
        resume: decision.resume,
        refreshSavedGames: decision.refreshSavedGames,
      );
    }
    final saved = opponent == null ? null : session.savedMatches[opponent];
    var nextSession = session.reduce(cm);
    if (nextSession.board == null && opponent != null) {
      nextSession = nextSession.copyWith(
        savedMatches: {
          ...nextSession.savedMatches,
          opponent:
              saved ??
              SavedMatchInfo(
                opponent: opponent,
                availability: SavedMatchAvailability.ready,
              ),
        },
      );
    }
    return FibsProtocolTransition(
      state: copyWith(session: nextSession, resume: decision.resume),
      commands: const ['board'],
    );
  }

  FibsProtocolTransition receiveResumeMatchRequest(CookieMessage cm) {
    final clearedResume = resume.clearDelayForCookie(cm);
    final opponent = cm.crumbOrNull(FibsCrumbKeys.name);
    final joining = clearedResume.shouldJoinPromptFrom(opponent);
    var nextSession = session.reduce(cm);
    final commands = <String>[];
    if (joining) {
      commands.add('join $opponent');
      nextSession = nextSession.joined();
    }
    return FibsProtocolTransition(
      state: copyWith(session: nextSession, resume: clearedResume),
      commands: commands,
    );
  }

  FibsProtocolTransition receiveTypeJoin(CookieMessage cm) {
    final opponent = cm.crumbOrNull(FibsCrumbKeys.opponent);
    final joining = resume.shouldJoinPromptFrom(opponent);
    var nextSession = session.reduce(cm);
    final commands = <String>[];
    if (joining) {
      commands.add('join $opponent');
      nextSession = nextSession.joined();
    }
    return FibsProtocolTransition(
      state: copyWith(session: nextSession),
      commands: commands,
    );
  }

  FibsProtocolTransition applyAndAutoJoin(CookieMessage cm) {
    var nextSession = session.reduce(cm);
    final commands = <String>[];
    if (nextSession.mustJoin) {
      commands.add('join');
      nextSession = nextSession.joined();
    }
    return FibsProtocolTransition(
      state: copyWith(session: nextSession),
      commands: commands,
    );
  }

  FibsProtocolTransition receiveTurnText(CookieMessage cm) {
    final nextSession = session.reduce(cm);
    final needsBoard =
        nextSession.board != null &&
        !nextSession.canRoll &&
        !nextSession.canMoveNow &&
        !nextSession.isGameOver;
    return FibsProtocolTransition(
      state: copyWith(session: nextSession),
      commands: needsBoard ? const ['board'] : const [],
    );
  }

  FibsProtocolTransition receiveMovePrompt(CookieMessage cm) {
    final nextSession = session.reduce(cm);
    return FibsProtocolTransition(
      state: copyWith(session: nextSession),
      commands: nextSession.canMoveNow ? const [] : const ['board'],
    );
  }

  FibsProtocolTransition receiveBoardRefreshText(CookieMessage _) =>
      FibsProtocolTransition(
        state: this,
        commands: session.board == null ? const [] : const ['board'],
      );

  FibsProtocolTransition receiveCantMoveText(CookieMessage cm) {
    final nextSession = session.reduce(cm);
    return FibsProtocolTransition(
      state: copyWith(session: nextSession),
      commands: nextSession.board == null ? const [] : const ['board'],
    );
  }

  FibsProtocolTransition receiveOwnInfo(CookieMessage cm) {
    final transition = settings.negotiate(
      doublePrompt: cm.crumbOrNull('double'),
      moreboards: cm.crumbOrNull('moreboards'),
    );

    return FibsProtocolTransition(
      state: copyWith(settings: transition.state),
      commands: transition.commands,
      trackSessionTransition: false,
    );
  }

  FibsProtocolTransition receiveChatMessage(CookieMessage cm) {
    final message = fibsProtocolChatMessage(cm);
    final delay = FibsResumeCoordinator.parseDelay(message.from, message.text);
    return delay == null
        ? FibsProtocolTransition(
            state: this,
            messages: [message],
            trackSessionTransition: false,
          )
        : recordResumeDelay(delay, message: message);
  }

  FibsProtocolTransition refreshWhoList() =>
      FibsProtocolTransition(state: this, commands: const ['who']);

  FibsProtocolTransition inviteBotByName(
    String user, {
    required int matchLength,
  }) => FibsProtocolTransition(
    state: copyWith(resume: resume.allowBoardAdmission()),
    commands: ['invite $user $matchLength'],
  );

  FibsProtocolTransition resignNormalLoss() =>
      FibsProtocolTransition(state: this, commands: const ['resign n']);

  FibsProtocolTransition courtesyDisconnect() =>
      FibsProtocolTransition(state: this, commands: const ['bye']);

  FibsProtocolTransition inviteBot(String user, {required int matchLength}) =>
      inviteBotByName(user, matchLength: matchLength);

  FibsProtocolTransition resumeSavedMatch(String opponent) {
    final nextResume = resume.beginAttempt(opponent);
    final shouldJoin =
        session.resumeRequestFrom?.toLowerCase() == opponent.toLowerCase();
    if (shouldJoin) {
      return FibsProtocolTransition(
        state: copyWith(session: session.joined(), resume: nextResume),
        commands: ['join $opponent'],
      );
    }
    return FibsProtocolTransition(
      state: copyWith(resume: nextResume),
      commands: ['invite $opponent'],
    );
  }

  FibsProtocolTransition resumeActiveMatch(String opponent) {
    final nextResume = resume.beginAttempt(opponent);
    return FibsProtocolTransition(
      state: copyWith(resume: nextResume),
      commands: const ['board'],
    );
  }

  FibsProtocolTransition joinGame([String? opponent]) => FibsProtocolTransition(
    state: copyWith(
      session: session.joined(),
      resume: resume.allowBoardAdmission(),
    ),
    commands: [if (opponent == null) 'join' else 'join $opponent'],
  );

  FibsProtocolTransition startRoll() {
    final plan = fibsStartRoll(session);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition submitTurn(List<GammonMove> moves) {
    final plan = fibsSubmitTurn(session, moves);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition commitTurnCommand(String command) {
    final plan = fibsCommitTurnCommand(session, command);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition offerDouble() {
    final plan = fibsOfferDouble(session);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition acceptDouble() {
    final plan = fibsAcceptDouble(session);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition rejectDouble() {
    final plan = fibsRejectDouble(session);
    return FibsProtocolTransition(
      state: copyWith(session: plan.session),
      commands: plan.commands,
    );
  }

  FibsProtocolTransition leaveGame() {
    final opponent = session.board?.opponentNameFor(session.user);
    return FibsProtocolTransition(
      state: copyWith(
        session: session.outOfGame(savedOpponent: opponent),
        resume: resume.suppressBoards(),
      ),
      commands: const ['leave', 'show savedgames'],
    );
  }

  FibsProtocolTransition returnToLobby() => FibsProtocolTransition(
    state: copyWith(
      session: session.outOfGame(),
      resume: resume.suppressBoards(),
    ),
  );

  FibsProtocolTransition watchedGameFinished() => returnToLobby();

  FibsProtocolTransition watch(String user) => FibsProtocolTransition(
    state: copyWith(
      session: session.outOfGame(),
      resume: resume.allowBoardAdmission(),
    ),
    commands: ['watch $user'],
  );

  FibsProtocolTransition stopWatching() => FibsProtocolTransition(
    state: copyWith(
      session: session.outOfGame(),
      resume: resume.suppressBoards(),
    ),
    commands: const ['unwatch'],
  );

  FibsProtocolTransition commandRejected(CookieMessage cm) {
    final rejected = resume.clearRejected(cm.cookie);
    return FibsProtocolTransition(
      state: copyWith(
        session: session.commandRejected(),
        resume: rejected.resume,
      ),
      signals: const {FibsProtocolSignal.commandRejected},
      messages: [fibsProtocolSystemMessage(cm)],
      trackSessionTransition: false,
    );
  }

  FibsProtocolTransition systemMessage(CookieMessage cm) {
    final rejected = resume.clearRejected(cm.cookie);
    return FibsProtocolTransition(
      state: copyWith(resume: rejected.resume),
      messages: [fibsProtocolSystemMessage(cm)],
      trackSessionTransition: false,
    );
  }

  FibsProtocolTransition receiveGameSavedByOpponent(CookieMessage cm) {
    final opponent =
        cm.crumbOrNull(FibsCrumbKeys.opponent) ??
        session.board?.opponentNameFor(session.user);
    return FibsProtocolTransition(
      state: copyWith(
        session: session.outOfGame(savedOpponent: opponent),
        resume: resume.suppressBoards(),
      ),
      commands: const ['show savedgames'],
      messages: [fibsProtocolSystemMessage(cm)],
      trackSessionTransition: false,
    );
  }

  FibsProtocolTransition recordResumeDelay(
    ResumeDelayInfo delay, {
    FibsProtocolMessage? message,
  }) => FibsProtocolTransition(
    state: copyWith(resume: resume.recordDelay(delay)),
    messages: [if (message != null) message],
    trackSessionTransition: false,
  );

  FibsProtocolTransition _applyCookie(
    CookieMessage cm,
    FibsResumeCoordinator resumeState,
  ) {
    final nextResume = resumeState
        .clearDelayForCookie(cm)
        .clearAttemptForCookie(cm);
    return FibsProtocolTransition(
      state: copyWith(session: session.reduce(cm), resume: nextResume),
      signals: switch (cm.cookie) {
        FibsCookie.FIBS_Board => const {FibsProtocolSignal.boardFrame},
        FibsCookie.FIBS_PlayerRolls => const {
          FibsProtocolSignal.opponentRolled,
        },
        _ => const {},
      },
      matchResult: fibsProtocolMatchResult(cm),
    );
  }

  FibsProtocolTransition _parkSavedMatchInLobby(
    String? opponent, {
    required FibsResumeCoordinator resume,
    required bool refreshSavedGames,
  }) => FibsProtocolTransition(
    state: copyWith(
      session: session.outOfGame(savedOpponent: opponent),
      resume: resume,
    ),
    commands: refreshSavedGames ? const ['leave', 'show savedgames'] : const [],
  );

  FibsProtocolState _copyWithResume(FibsResumeCoordinator resume) =>
      copyWith(resume: resume);
}
