import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

void main() {
  // The board is a typed domain structure (GammonBoard) over the raw list. Pin
  // its typed accessors AND that it's still a drop-in List<List<int>> (a
  // zero-cost extension type), so callers can use either surface.
  test('GammonBoard exposes typed accessors and stays a drop-in list', () {
    final raw = List.generate(26, (_) => <int>[]);
    raw[6] = [-1, -2, -3]; // three player-one checkers (negative ids)
    raw[13] = [4, 5]; // two player-two checkers (positive ids)
    final board = GammonBoard(raw);

    expect(board.countAt(6), 3);
    expect(board.countAt(1), 0);
    expect(board.isVacantAt(1), isTrue);
    expect(board.isVacantAt(6), isFalse);
    expect(board.ownerAt(6), GammonPlayer.one); // negative -> player one
    expect(board.ownerAt(13), GammonPlayer.two); // positive -> player two
    expect(board.ownerAt(1), isNull); // empty point has no owner
    expect(board.checkersAt(13), [4, 5]);

    // drop-in: still usable everywhere a List<List<int>> is expected
    expect(board.length, 26);
    expect(board[6], [-1, -2, -3]);
    final List<List<int>> asList = board; // assignable without a cast
    expect(asList[13], [4, 5]);
  });
}
