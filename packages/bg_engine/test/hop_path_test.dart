import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

void main() {
  group('consumeHopPath', () {
    test('a single-die move has no intermediate pip', () {
      final dice = [6, 5];
      // player one moves 24 -> 18 (a 6): one hop, endpoints only
      final path = consumeHopPath(
        fromPip: 24,
        toPip: 18,
        player: GammonPlayer.one,
        dice: dice,
      );
      expect(path, [24, 18]);
      expect(dice, [5], reason: 'only the 6 was consumed');
    });

    test('a two-die move shows the intermediate pip (player one)', () {
      final dice = [6, 5];
      // 24 -> 13 is 11 = 6 + 5; larger die first -> stop at 18
      final path = consumeHopPath(
        fromPip: 24,
        toPip: 13,
        player: GammonPlayer.one,
        dice: dice,
      );
      expect(path, [24, 18, 13]);
      expect(dice, isEmpty, reason: 'both dice consumed');
    });

    test('a two-die move shows the intermediate pip (player two)', () {
      final dice = [3, 4];
      // player two moves 1 -> 8 (7 = 3 + 4); larger first -> stop at 5
      final path = consumeHopPath(
        fromPip: 1,
        toPip: 8,
        player: GammonPlayer.two,
        dice: dice,
      );
      expect(path, [1, 5, 8]);
    });

    test('doubles show every intermediate pip', () {
      final dice = [3, 3, 3, 3];
      // 24 -> 12 is 12 = 3+3+3+3: stop at 21, 18, 15
      final path = consumeHopPath(
        fromPip: 24,
        toPip: 12,
        player: GammonPlayer.one,
        dice: dice,
      );
      expect(path, [24, 21, 18, 15, 12]);
      expect(dice, isEmpty);
    });

    test(
      'an undecomposable distance (e.g. a bear-off overshoot) is direct',
      () {
        final dice = [6, 4];
        // a checker on point 2 borne off (toPip 0) with a 6: distance 2, no
        // subset of {6,4} sums to 2 -> a single segment, dice untouched
        final path = consumeHopPath(
          fromPip: 2,
          toPip: 0,
          player: GammonPlayer.one,
          dice: dice,
        );
        expect(path, [2, 0]);
        expect(dice, [6, 4]);
      },
    );

    test('prefers the fewest dice when several subsets fit', () {
      final dice = [2, 2, 4];
      // distance 4 could be [4] or [2,2]; prefer the single die -> no hop
      final path = consumeHopPath(
        fromPip: 10,
        toPip: 6,
        player: GammonPlayer.one,
        dice: dice,
      );
      expect(path, [10, 6]);
      expect(dice, [2, 2], reason: 'the single 4 was used, not two 2s');
    });
  });
}
