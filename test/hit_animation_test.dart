import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

List<List<int>> _copy(List<List<int>> board) =>
    List<List<int>>.generate(board.length, (i) => List<int>.from(board[i]));

void main() {
  group('MoveAnimation.forMove (issue #5)', () {
    test('a hit delays the hittee until the hitter arrives', () {
      // player1 (id -1) on pip 8 hits player2 blot (id 1) on pip 5 with a 3
      final initial = makeBoard({8: -1, 5: 1});
      final deltas = GammonRules.applyMove(
        _copy(initial),
        GammonMove(fromPipNo: 8, toPipNo: 5),
      );
      expect(deltas, isNotEmpty);

      final anim = MoveAnimation.forMove(initial, deltas);

      // the hittee (id 1) waits, the hitter (id -1) does not
      expect(anim.delays[1], isNotNull);
      expect(anim.delays[1]!.inMilliseconds, greaterThan(0));
      expect(anim.delays.containsKey(-1), isFalse);

      // both pieces still have animation paths
      expect(anim.layouts.containsKey(-1), isTrue);
      expect(anim.layouts.containsKey(1), isTrue);
    });

    test('a plain move has no delays', () {
      final initial = makeBoard({8: -1});
      final deltas = GammonRules.applyMove(
        _copy(initial),
        GammonMove(fromPipNo: 8, toPipNo: 5),
      );

      final anim = MoveAnimation.forMove(initial, deltas);

      expect(anim.delays, isEmpty);
      expect(anim.layouts.containsKey(-1), isTrue);
    });
  });
}
