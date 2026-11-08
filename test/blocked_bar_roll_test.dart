import 'dart:math';

import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Roll42 implements Random {
  int index = 0;
  @override
  int nextInt(int max) => [3, 1][index++ % 2];
  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('bar entry preserves a die usable later in the same turn', () {
    final board = Position(
      points: const [
        -2,
        -3,
        1,
        0,
        0,
        -2,
        0,
        0,
        0,
        0,
        0,
        2,
        -5,
        0,
        0,
        2,
        3,
        0,
        4,
        0,
        2,
        0,
        0,
        -3,
      ],
      twoBar: 1,
    ).toBoard();
    final game = GammonState.from(
      board: board,
      dice: const [],
      turnPlayer: GammonPlayer.two,
      random: _Roll42(),
    );
    game.rollTurn();
    expect(game.dice.where((die) => die.available).map((die) => die.roll), [
      4,
      2,
    ]);
    final first = game.getAllLegalMoves()[0]!.first;
    game.applyMove(move: first);
    expect(game.dice.any((die) => die.roll == 2 && die.available), isTrue);
    expect(game.getAllLegalMoves(), isNotEmpty);
    game.dispose();
  });
}
