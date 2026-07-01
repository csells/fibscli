import 'dart:async';

import 'package:fibscli/board_animator.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

PieceLayout _layout(int id, double dx) =>
    PieceLayout(pipNo: 1, pieceID: id, offset: Offset(dx, 0), label: '');

// a one-piece animation tweening id 5 from x=0 to x=100
MoveAnimation _anim() => MoveAnimation({
  5: [_layout(5, 0), _layout(5, 100)],
}, const {});

void main() {
  test('an empty animation does nothing and completes immediately', () async {
    final animator = BoardAnimator();
    var notified = false;
    animator.addListener(() => notified = true);

    await animator.play(MoveAnimation(const {}, const {})); // already done

    expect(animator.isAnimating, isFalse);
    expect(animator.layouts, isEmpty);
    expect(notified, isFalse);
  });

  test('play installs the layouts and notifies', () {
    final animator = BoardAnimator();
    var notifications = 0;
    animator.addListener(() => notifications++);

    final done = animator.play(_anim());

    expect(animator.isAnimating, isTrue);
    expect(animator.layouts.containsKey(5), isTrue);
    expect(notifications, 1);
    expect(done, isA<Future<void>>());
  });

  test('the play future completes only once the last piece ends', () async {
    final animator = BoardAnimator();
    var completed = false;
    unawaited(animator.play(_anim()).then((_) => completed = true));

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse, reason: 'still animating');

    animator.endPiece(5); // the only piece finishes
    await Future<void>.delayed(Duration.zero);

    expect(completed, isTrue);
    expect(animator.isAnimating, isFalse);
    expect(animator.layouts, isEmpty);
  });

  // Regression: play() asserted _layouts.isEmpty, so a second move started
  // before the first settled (a fast double-tap, or an AI move on the tail of
  // the human's animation) threw / clobbered the in-flight tweens. play() now
  // serializes: the second waits for the first to finish.
  test('a second play() while animating serializes, not asserts', () async {
    final animator = BoardAnimator();
    final order = <String>[];
    final f1 = animator
        .play(
          MoveAnimation({
            5: [_layout(5, 0), _layout(5, 100)],
          }, const {}),
        )
        .then((_) => order.add('a'));
    expect(animator.isAnimating, isTrue);

    // second play while the first is still in flight -- must NOT throw
    final f2 = animator
        .play(
          MoveAnimation({
            6: [_layout(6, 0), _layout(6, 100)],
          }, const {}),
        )
        .then((_) => order.add('b'));

    // only the first animation is installed so far; the second is queued
    expect(animator.layouts.containsKey(5), isTrue);
    expect(animator.layouts.containsKey(6), isFalse);

    animator.endPiece(5); // first finishes -> second starts
    await f1;
    await Future<void>.delayed(Duration.zero); // let the queued play B install
    expect(animator.isAnimating, isTrue);
    expect(animator.layouts.containsKey(6), isTrue);

    animator.endPiece(6);
    await f2;
    expect(order, ['a', 'b']); // serialized in order
    expect(animator.isAnimating, isFalse);
  });

  test('endPiece notifies (to redraw the settled board) only when empty', () {
    final animator = BoardAnimator();
    unawaited(
      animator.play(
        MoveAnimation({
          5: [_layout(5, 0), _layout(5, 100)],
          6: [_layout(6, 0), _layout(6, 100)],
        }, const {}),
      ),
    );
    var notifications = 0;
    animator.addListener(() => notifications++);

    animator.endPiece(5); // one of two: no redraw yet
    expect(notifications, 0);
    animator.endPiece(6); // last one: redraw the final board
    expect(notifications, 1);
  });
}
