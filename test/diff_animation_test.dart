import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<int>> _copy(List<List<int>> b) => [
  for (final c in b) List<int>.of(c),
];

void main() {
  test('MoveAnimation.between tweens a move from source to destination', () {
    final from = GammonRules.initialBoard();
    final to = _copy(from);
    GammonRules.applyMove(
      to,
      GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
    );

    final anim = MoveAnimation.between(from, to);
    expect(anim.layouts.length, 1); // exactly one checker moved
    final frames = anim.layouts.values.single;
    expect(frames.first.pipNo, 24); // starts where it left
    expect(frames.last.pipNo, 23); // ends where it landed
    expect(anim.delays, isEmpty);
  });

  test('an unchanged board produces no animation', () {
    final board = GammonRules.initialBoard();
    expect(MoveAnimation.between(board, _copy(board)).layouts, isEmpty);
  });

  test('a multi-hop move animates through the intermediate pip', () {
    // a single player-one checker journeys 24 -> 18 -> 13 using a 6 then a 5.
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(-1);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[13].add(-1);

    final anim = MoveAnimation.between(from, to, dice: [6, 5]);
    final frames = anim.layouts.values.single;
    // MUST pass through 18, not jump 24 -> 13
    expect(frames.map((f) => f.pipNo).toList(), [24, 18, 13]);
  });

  test('without dice a move stays a direct two-frame tween', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(-1);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[13].add(-1);

    final frames = MoveAnimation.between(from, to).layouts.values.single;
    expect(frames.map((f) => f.pipNo).toList(), [24, 13]);
  });

  test('an intermediate hop lands on the real point slot', () {
    // baseSlotOffset (used for pass-through pips) must match where getLayouts
    // actually draws a lone checker on that point, so a hop looks right.
    for (final pip in [1, 6, 7, 12, 13, 18, 19, 24]) {
      final board = List<List<int>>.generate(26, (_) => <int>[]);
      board[pip].add(-1);
      final real = PieceLayout.getLayouts(board).single.offset;
      expect(PieceLayout.baseSlotOffset(pip), real, reason: 'pip $pip');
    }
  });

  test('a single-die move has no intermediate frame even with dice', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(-1);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[18].add(-1);

    final frames = MoveAnimation.between(
      from,
      to,
      dice: [6, 5],
    ).layouts.values.single;
    expect(frames.map((f) => f.pipNo).toList(), [24, 18]);
  });
}
