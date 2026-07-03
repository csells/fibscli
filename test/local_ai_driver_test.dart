import 'dart:math';

import 'package:fibscli/local_ai_driver.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (PubevalAiPlayer, …)
import 'package:flutter_test/flutter_test.dart';

// player two (on roll) all but home, player one stacked far back: a pure race
// the AI wins almost surely, so it should double before rolling.
GammonState _aiDominatingGame() {
  final position = Position(
    points: const [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -15, // point 12: all 15 of player one's checkers, far back
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      1, // point 24: player two's last checker
    ],
    twoOff: 14,
  );
  return GammonState.from(
    board: position.toBoard(),
    dice: const [],
    turnPlayer: GammonPlayer.two,
  );
}

// A pubeval player that also resigns: [resignAs] scripts the resignation
// verdict and every decision method records its call order, so the tests can
// pin that resignation is consulted first and short-circuits the turn.
class _ResigningAi extends PubevalAiPlayer {
  _ResigningAi(this.resignAs);

  final BgResignDecision resignAs;
  final calls = <String>[];

  @override
  Future<BgResignDecision> resignDecision(BgPosition position) async {
    calls.add('resign');
    return resignAs;
  }

  @override
  Future<BgCubeAction> cubeDecision(BgPosition position) {
    calls.add('cube');
    return super.cubeDecision(position);
  }

  @override
  Future<BgTurn> chooseTurn(BgPosition position) {
    calls.add('choose');
    return super.chooseTurn(position);
  }
}

void main() {
  test('positionFromState mirrors the live game state', () {
    final state = GammonState();
    final pos = positionFromState(state);

    expect(pos.onRoll, state.turnPlayer);
    expect(pos.dice, state.dice.where((d) => d.available).map((d) => d.roll));
    // a deep copy: mutating the snapshot must not touch the game
    pos.board[1].add(999);
    expect(state.board[1], isNot(contains(999)));
  });

  test('playAiTurn makes a move and passes the turn', () async {
    final state = GammonState();
    final mover = state.turnPlayer;
    final moveNo = state.moveNo;

    await playAiTurn(state, PubevalAiPlayer());

    // either the turn passed to the opponent, or the AI bore off the last
    // checker and the game ended on this very turn
    expect(state.gameOver || state.turnPlayer != mover, isTrue);
    if (!state.gameOver) expect(state.moveNo, greaterThan(moveNo));
  });

  test('playAiTurn offers a double from a dominating position', () async {
    final game = _aiDominatingGame();
    var proposed = 0;
    await playAiTurn(
      game,
      PubevalAiPlayer(),
      onOfferDouble: (value) async {
        proposed = value; // the human is asked to take/pass
        return true; // take
      },
    );
    expect(proposed, 2, reason: 'a centered cube doubles from 1 to 2');
    expect(game.cube.value, 2, reason: 'the taken double raised the stake');
  });

  test('playAiTurn ends the game when the human passes the double', () async {
    final game = _aiDominatingGame();
    await playAiTurn(
      game,
      PubevalAiPlayer(),
      onOfferDouble: (_) async => false, // pass
    );
    expect(game.gameOver, isTrue, reason: 'passing the cube concedes the game');
  });

  test('playAiTurn surfaces each checker move to onMove', () async {
    final game = GammonState();
    final moves = <GammonMove>[];
    await playAiTurn(
      game,
      PubevalAiPlayer(),
      onMove: (move) async {
        moves.add(move);
        game.applyMove(
          move: move,
        ); // the host applies (as the UI animator does)
      },
    );
    // a normal opening turn plays at least one checker; onMove saw them all
    expect(moves, isNotEmpty);
  });

  test('playAiTurn resigns the game when the engine says to', () async {
    final game = GammonState();
    final aiSide = game.turnPlayer!;
    final ai = _ResigningAi(BgResignDecision.resignGammon);
    BgResignDecision? surfaced;
    final moveNo = game.moveNo;

    await playAiTurn(
      game,
      ai,
      onResign: (decision) async => surfaced = decision,
    );

    expect(game.gameOver, isTrue, reason: 'the resignation concedes the game');
    expect(game.winner, GammonRules.otherPlayer(aiSide));
    expect(surfaced, BgResignDecision.resignGammon);
    // resignation is decided first and ends the turn: no cube offer, no play
    expect(ai.calls, ['resign']);
    expect(game.moveNo, moveNo, reason: 'no checkers were played');
  });

  test('playAiTurn plays on when the engine does not resign', () async {
    final game = GammonState();
    final ai = _ResigningAi(BgResignDecision.playOn);

    await playAiTurn(game, ai);

    expect(ai.calls.first, 'resign');
    expect(ai.calls, contains('choose'));
    expect(game.winner, isNull);
  });

  test('two pubeval AIs play a full local game to completion', () async {
    final state = GammonState(random: Random(1));
    final ai = PubevalAiPlayer();

    var turns = 0;
    while (!state.gameOver && turns < 1000) {
      await playAiTurn(state, ai);
      turns++;
    }

    expect(state.gameOver, isTrue, reason: 'game should finish, not stall');
    // the winner has borne off all 15 checkers
    final p1Off = state.board[0].where((p) => p < 0).length;
    final p2Off = state.board[25].where((p) => p > 0).length;
    expect(p1Off == 15 || p2Off == 15, isTrue);
  });
}
