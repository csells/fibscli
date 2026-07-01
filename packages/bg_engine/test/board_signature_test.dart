import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

void main() {
  group('netSignature', () {
    test('is piece-id independent (only counts per pip matter)', () {
      final a = List<List<int>>.generate(26, (_) => <int>[]);
      a[6].addAll([-1, -2]); // two player-one checkers (ids -1,-2)
      a[13].addAll([1, 2, 3]); // three player-two checkers
      final b = List<List<int>>.generate(26, (_) => <int>[]);
      b[6].addAll([-9, -4]); // same counts, different ids
      b[13].addAll([7, 8, 9]);
      expect(netSignature(a), netSignature(b));
    });

    test('distinguishes different positions', () {
      final a = GammonRules.initialBoard();
      final b = GammonRules.copyBoard(a);
      GammonRules.applyMove(
        b,
        GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
      );
      expect(netSignature(a), isNot(netSignature(b)));
    });

    test('encodes ownership by sign (player one negative)', () {
      final board = List<List<int>>.generate(26, (_) => <int>[]);
      board[6].add(-1); // player one
      board[7].add(1); // player two
      final sig = netSignature(board).split(',');
      expect(sig[6], '-1');
      expect(sig[7], '1');
    });
  });
}
