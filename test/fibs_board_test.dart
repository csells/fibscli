import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

// Builds a FIBS boardstyle-3 `board:` line from a 26-int board array (FIBS
// frame: index 1..24 = points, positive = O, negative = X) plus the trailing
// game-state fields, so tests read as positions rather than colon soup.
String fibsBoardLine(
  List<int> points, {
  int turn = 1,
  List<int> oDice = const [0, 0],
  List<int> xDice = const [0, 0],
  int cube = 1,
  int xOff = 0,
  int oOff = 0,
  int xBar = 0,
  int oBar = 0,
  int canMove = 0,
}) {
  assert(points.length == 26);
  // player1 = X (-1 color, 24->1 direction); player2 = O.
  return [
    'board',
    'xplayer',
    'oplayer',
    '1', // match length
    '0', '0', // scores
    points.join(':'),
    '$turn',
    '${xDice[0]}:${xDice[1]}',
    '${oDice[0]}:${oDice[1]}',
    '$cube',
    '1', '1', // may double
    '0', // was doubled
    '-1', // player1 color = X
    '-1', // direction = 24->1
    '0', '25', // home/bar index hints (ignored)
    '$xOff', '$oOff', // player1Home, player2Home (borne off)
    '$xBar', '$oBar', // player1Bar, player2Bar (on the bar)
    '$canMove',
    '0', '0', // skipped
    '0', // redoubles
  ].join(':');
}

// parse a raw line as if the connection is past login (run state)
CookieMessage parse(String raw) {
  final monster = CookieMonster()
    ..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return monster.eatCookie(raw);
}

// counts per pip with the model's sign convention (negative = player1)
int _net(int id) => GammonRules.playerFor(id) == GammonPlayer.one ? -1 : 1;

List<int> _counts(List<List<int>> board) =>
    [for (final pip in board) pip.fold<int>(0, (sum, id) => sum + _net(id))];

void main() {
  // standard opening in the FIBS absolute frame (positive = O, negative = X)
  const opening = [
    0, 2, 0, 0, 0, 0, -5, 0, -3, 0, 0, 0, 5, //
    -5, 0, 0, 0, 3, 0, 5, 0, 0, 0, 0, -2, 0,
  ];

  group('FibsBoard.fromCrumbs (milestone 1)', () {
    test('the parser classifies a board: line as FIBS_Board', () {
      final cm = parse(fibsBoardLine(opening));
      expect(cm.cookie, FibsCookie.FIBS_Board);
      expect(cm.crumbs, isNotNull);
    });

    test('opening board maps to the engine initial position', () {
      final cm = parse(fibsBoardLine(opening, turn: 1));
      final game = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState();

      // point-for-point identical checker counts to the engine opening
      expect(_counts(game.board), _counts(GammonRules.initialBoard()));
      // turn = 1 means O = player2 is on roll
      expect(game.turnPlayer, GammonPlayer.two);
    });

    test('turn color -1 means X = player1 is on roll', () {
      final cm = parse(fibsBoardLine(opening, turn: -1));
      expect(FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().turnPlayer,
          GammonPlayer.one);
    });

    int countOn(List<List<int>> board, int pip, GammonPlayer player) =>
        board[pip].where((id) => GammonRules.playerFor(id) == player).length;

    test('bar counts land on the right player and pip', () {
      final cm = parse(fibsBoardLine(opening, xBar: 1, oBar: 1));
      final board = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().board;

      // player1 (X) bar is index 25; player2 (O) bar is index 0
      expect(countOn(board, 25, GammonPlayer.one), 1);
      expect(countOn(board, 0, GammonPlayer.two), 1);
    });

    test('borne-off counts land in the off trays', () {
      final cm = parse(fibsBoardLine(opening, xOff: 3, oOff: 2));
      final board = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().board;

      // player1 (X) off is index 0; player2 (O) home/off is index 25
      expect(countOn(board, 0, GammonPlayer.one), 3);
      expect(countOn(board, 25, GammonPlayer.two), 2);
    });
  });
}
