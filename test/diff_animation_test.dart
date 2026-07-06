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

  test('a bear-off animates the mover, not a same-pip bar checker', () {
    // Engine pip 25 is BOTH player1's bar and player2's off. player2 bears a
    // checker off (its 24-point -> off) while player1 sits on the bar. The
    // mover is player2's checker; player1's bar checker must stay put. take()
    // was owner-blind and picked the (first-emitted) bar layout, so the bar
    // checker animated instead of the borne-off one.
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(1); // player2 checker on its 24-point
    from[25].add(-1); // player1 checker on the bar
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[25].addAll([-1, 1]); // player1 still on bar; player2 checker borne off

    final anim = MoveAnimation.between(from, to);
    expect(anim.layouts.length, 1); // exactly one checker moved
    expect(anim.layouts.keys.single, isPositive); // player2's, not the bar (-1)
    expect(anim.layouts.containsKey(-1), isFalse);
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

  test('multi-checker board diffs animate one checker at a time', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(-1);
    from[13].add(-2);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[18].add(-1);
    to[8].add(-2);

    final anim = MoveAnimation.between(from, to, dice: [6, 5]);
    expect(anim.layouts.length, 2);
    expect(anim.delays.length, 1);
    expect(anim.delays.values.single, kHopAnimationDuration);
  });

  test('later checker waits for every hop in an earlier checker path', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[24].add(-1);
    from[13].add(-2);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[16].add(-1);
    to[9].add(-2);

    final anim = MoveAnimation.between(from, to, dice: [4, 4, 4, 4]);
    expect(anim.delays.values, contains(kHopAnimationDuration * 2));
  });

  test('board diffs preserve stationary stack slots', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[20].addAll([1, 2, 3]);
    from[22].addAll([4, 5]);
    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[20].addAll([1, 2]);
    to[22].addAll([3, 4, 5]);

    final anim = MoveAnimation.between(from, to, dice: [2]);
    final frames = anim.layouts.values.single;
    final fromSlots = PieceLayout.getLayouts(from).toList();
    final toSlots = PieceLayout.getLayouts(to).toList();
    PieceLayout topSlot(List<PieceLayout> slots, int pip) =>
        slots.lastWhere((layout) => layout.pipNo == pip);

    expect(frames.first.offset, topSlot(fromSlots, 20).offset);
    expect(frames.last.offset, topSlot(toSlots, 22).offset);
  });

  test('board diff hits land on the blot slot before the victim bars', () {
    final from = List<List<int>>.generate(26, (_) => <int>[]);
    from[14].add(1); // opponent checker
    from[20].add(-1); // our blot on the top row

    final to = List<List<int>>.generate(26, (_) => <int>[]);
    to[20].add(1); // the hitter owns the point after the hit
    to[25].add(-1); // our checker is on the bar

    final anim = MoveAnimation.between(from, to, dice: [6]);
    final hitter = anim.layouts.values.singleWhere(
      (frames) => frames.first.pipNo == 14,
    );
    final hittee = anim.layouts.values.singleWhere(
      (frames) => frames.first.pipNo == 20,
    );

    expect(hitter.last.pipNo, 20);
    expect(hitter.last.offset, PieceLayout.baseSlotOffset(20));
    expect(hittee.first.offset, PieceLayout.baseSlotOffset(20));
    expect(hittee.last.pipNo, 25);
    expect(anim.delays[hittee.last.pieceID], kHopAnimationDuration);
  });
}
