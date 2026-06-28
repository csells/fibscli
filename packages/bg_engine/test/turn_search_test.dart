import 'package:bg_engine/src/ai/turn_search.dart';
import 'package:bg_engine/src/rules.dart';
import 'package:test/test.dart';

void main() {
  group('enumerateLegalTurns', () {
    test('opening 3-1 yields turns that each consume both dice legally', () {
      final turns = enumerateLegalTurns(
        GammonRules.initialBoard(),
        GammonPlayer.one,
        [3, 1],
      );
      expect(turns, isNotEmpty);
      for (final turn in turns) {
        final hops = turn.moves.fold<int>(0, (s, m) => s + m.hops.length);
        expect(hops, 2, reason: 'forced rules require playing both dice');
      }
      // the classic 8/5 6/5 (make the 5-point) must be among the candidates;
      // for player one those are engine pips 8->5 and 6->5.
      final makesFivePoint = turns.any(
        (t) =>
            t.moves.any((m) => m.fromPipNo == 8 && m.toPipNo == 5) &&
            t.moves.any((m) => m.fromPipNo == 6 && m.toPipNo == 5),
      );
      expect(makesFivePoint, isTrue);
    });

    test('a dance yields a single empty turn', () {
      // player2 on the bar with points 1..6 blocked -> cannot enter
      final board = GammonRules.initialBoard();
      board[0]
        ..clear()
        ..add(50);
      for (var pip = 1; pip <= 6; ++pip) {
        board[pip]
          ..clear()
          ..addAll([-100 - pip, -200 - pip]);
      }
      final turns = enumerateLegalTurns(board, GammonPlayer.two, [6, 6, 6, 6]);
      expect(turns.length, 1);
      expect(turns.single.moves, isEmpty);
    });
  });
}
