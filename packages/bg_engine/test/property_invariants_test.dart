import 'dart:math';

import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// Property-based engine tests: instead of hand-picking positions, play many
// random-but-legal games from a seeded PRNG and assert invariants that must
// hold at EVERY reachable position. A seeded Random keeps failures
// reproducible; a counterexample prints the offending board.

const _seeds = [1, 7, 42, 99, 256, 1000, 31337, 65535];

// every player checker, wherever it is (points + bar + off), must always total
// 15 -- nothing is ever created or destroyed.
void _expectConserved(List<List<int>> board, String where) {
  final p = Position.fromBoard(board);
  for (final player in GammonPlayer.values) {
    expect(
      p.totalFor(player),
      15,
      reason: '$where: $player should always own 15 checkers\n$p',
    );
  }
}

// no point (1..24) may hold checkers of both players at once. Cells 0 and 25
// are exempt by design: each is one player's off tray AND the other's bar.
void _expectSingleOwner(List<List<int>> board, String where) {
  for (var pip = 1; pip <= 24; pip++) {
    final signs = board[pip].map((id) => id.sign).toSet();
    expect(
      signs.length,
      lessThanOrEqualTo(1),
      reason: '$where: pip $pip has mixed owners ${board[pip]}',
    );
  }
}

void main() {
  test('random self-play preserves the core board invariants', () {
    for (final seed in _seeds) {
      final rng = Random(seed);
      var board = GammonRules.initialBoard();
      var player = GammonPlayer.one;

      _expectConserved(board, 'seed $seed opening');

      for (var turn = 0; turn < 60; turn++) {
        final a = rng.nextInt(6) + 1;
        final b = rng.nextInt(6) + 1;
        final dice = a == b ? [a, a, a, a] : [a, b];

        final turns = enumerateLegalTurns(board, player, dice);
        expect(turns, isNotEmpty, reason: 'seed $seed: never empty (dance ok)');

        final chosen = turns[rng.nextInt(turns.length)];
        final where = 'seed $seed turn $turn ($player rolled $dice)';

        // the chosen turn never moves more than the dice allow
        expect(
          chosen.moves.fold<int>(0, (n, m) => n + m.hops.length),
          lessThanOrEqualTo(dice.length),
          reason: '$where: played more hops than dice',
        );

        board = chosen.board;
        _expectConserved(board, where);
        _expectSingleOwner(board, where);

        // a borne-off win ends the game; start a fresh one for more coverage
        if (Position.fromBoard(board).offFor(player) == 15) {
          board = GammonRules.initialBoard();
        }
        player = GammonRules.otherPlayer(player);
      }
    }
  });

  test(
    'Position round-trips through the engine board for random positions',
    () {
      final rng = Random(2024);
      var board = GammonRules.initialBoard();
      var player = GammonPlayer.one;

      for (var turn = 0; turn < 200; turn++) {
        final a = rng.nextInt(6) + 1;
        final b = rng.nextInt(6) + 1;
        final dice = a == b ? [a, a, a, a] : [a, b];
        final turns = enumerateLegalTurns(board, player, dice);
        board = turns[rng.nextInt(turns.length)].board;

        // fromBoard -> toBoard -> fromBoard must be a fixed point: the typed
        // Position fully and losslessly captures the checker layout.
        final position = Position.fromBoard(board);
        expect(Position.fromBoard(position.toBoard()), position);

        if (position.offFor(player) == 15) board = GammonRules.initialBoard();
        player = GammonRules.otherPlayer(player);
      }
    },
  );

  test('win probability stays a valid probability for random positions', () {
    final rng = Random(808);
    var board = GammonRules.initialBoard();
    var player = GammonPlayer.one;

    for (var turn = 0; turn < 120; turn++) {
      final a = rng.nextInt(6) + 1;
      final b = rng.nextInt(6) + 1;
      final dice = a == b ? [a, a, a, a] : [a, b];
      final turns = enumerateLegalTurns(board, player, dice);
      board = turns[rng.nextInt(turns.length)].board;

      final wp = CubePolicy.winProbability(board, player);
      expect(wp, greaterThan(0), reason: 'turn $turn: $wp not > 0');
      expect(wp, lessThan(1), reason: 'turn $turn: $wp not < 1');

      if (Position.fromBoard(board).offFor(player) == 15) {
        board = GammonRules.initialBoard();
      }
      player = GammonRules.otherPlayer(player);
    }
  });
}
