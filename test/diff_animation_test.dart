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
}
