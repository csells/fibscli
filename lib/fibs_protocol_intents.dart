import 'package:flutter/foundation.dart';

import 'fibs_move.dart';
import 'fibs_session.dart';
import 'model.dart';

final _turnCommandPattern = RegExp(
  r'^move(?: (?:bar|[1-9]|1[0-9]|2[0-4])-(?:off|[1-9]|1[0-9]|2[0-4]))*$',
);

class FibsProtocolError implements Exception {
  const FibsProtocolError(this.message);

  final String message;

  @override
  String toString() => 'FibsProtocolError: $message';
}

@immutable
class FibsProtocolIntentPlan {
  const FibsProtocolIntentPlan({required this.session, required this.commands});

  final FibsSession session;
  final List<String> commands;
}

bool isFibsWholeTurnMoveCommand(String command) =>
    _turnCommandPattern.hasMatch(command);

FibsProtocolIntentPlan fibsStartRoll(FibsSession session) {
  if (!session.canRoll) {
    throw FibsProtocolError(
      'roll: not our turn to roll '
      '(isMyTurn=${session.isMyTurn} dice=${session.effectiveDice})',
    );
  }
  return FibsProtocolIntentPlan(
    session: session.startedRolling(),
    commands: const ['roll'],
  );
}

FibsProtocolIntentPlan fibsSubmitTurn(
  FibsSession session,
  List<GammonMove> moves,
) {
  if (!session.canMoveNow) {
    throw FibsProtocolError(
      'submitTurn: not our turn to move '
      '(isMyTurn=${session.isMyTurn} dice=${session.effectiveDice})',
    );
  }
  return FibsProtocolIntentPlan(
    session: session.committed(),
    commands: [if (moves.isNotEmpty) fibsTurnCommand(moves)],
  );
}

FibsProtocolIntentPlan fibsCommitTurnCommand(
  FibsSession session,
  String command,
) {
  if (!isFibsWholeTurnMoveCommand(command)) {
    throw ArgumentError.value(
      command,
      'command',
      'expected a FIBS whole-turn move command',
    );
  }
  if (!session.canMoveNow) {
    throw FibsProtocolError(
      'commitTurnCommand: not our turn to move '
      '(isMyTurn=${session.isMyTurn} dice=${session.effectiveDice})',
    );
  }
  return FibsProtocolIntentPlan(
    session: session.committed(),
    commands: [command],
  );
}

FibsProtocolIntentPlan fibsOfferDouble(FibsSession session) {
  if (!session.canOfferDouble) {
    throw FibsProtocolError(
      'offerDouble: can only double on our turn before '
      'rolling when FIBS allows it '
      '(isMyTurn=${session.isMyTurn} dice=${session.effectiveDice} '
      'canRoll=${session.canRoll})',
    );
  }
  return FibsProtocolIntentPlan(
    session: session.committed(),
    commands: const ['double'],
  );
}

FibsProtocolIntentPlan fibsAcceptDouble(FibsSession session) {
  if (!session.doubleOffered) {
    throw const FibsProtocolError('acceptDouble: no double has been offered');
  }
  return FibsProtocolIntentPlan(
    session: session.doubleResolved(),
    commands: const ['accept'],
  );
}

FibsProtocolIntentPlan fibsRejectDouble(FibsSession session) {
  if (!session.doubleOffered) {
    throw const FibsProtocolError('rejectDouble: no double has been offered');
  }
  return FibsProtocolIntentPlan(
    session: session.doubleResolved(),
    commands: const ['reject'],
  );
}
