import 'dart:math';

import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// enumerateLegalTurns is built ON TOP of GammonRules.getForcedLegalMoves (it
// recurses through it), so the forced-move rules live in exactly one place.
// This pins that relationship: every turn the enumerator emits must play the
// maximum number of dice the rules allow -- if the recursion/pruning ever
// emitted a non-maximal turn, or maxPlayableDice and the enumerator diverged,
// this fails.
void main() {
  test('every enumerated turn plays the maximum playable dice', () {
    final rng = Random(12345);
    var board = GammonRules.initialBoard();
    var player = GammonPlayer.one;

    for (var t = 0; t < 200; t++) {
      final a = rng.nextInt(6) + 1;
      final b = rng.nextInt(6) + 1;
      final dice = a == b ? [a, a, a, a] : [a, b];

      final maxDice = GammonRules.maxPlayableDice(board, player, dice);
      final turns = enumerateLegalTurns(board, player, dice);

      for (final turn in turns) {
        final hops = turn.moves.fold<int>(0, (s, m) => s + m.hops.length);
        expect(
          hops,
          maxDice,
          reason:
              'turn $t ($player, dice $dice): a non-maximal turn slipped '
              'through -- enumerator and forced-move rules disagree',
        );
      }

      // advance the game by playing one of the enumerated turns
      final chosen = turns[rng.nextInt(turns.length)];
      board = chosen.board;
      if (Position.fromBoard(board).offFor(player) == 15) {
        board = GammonRules.initialBoard();
      }
      player = GammonRules.otherPlayer(player);
    }
  });
}
