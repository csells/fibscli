import 'package:fibscli/local_ai_driver.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (PubevalAiPlayer, …)
import 'package:flutter_test/flutter_test.dart';

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

  test('two pubeval AIs play a full local game to completion', () async {
    final state = GammonState();
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
