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

List<int> _counts(List<List<int>> board) => [
  for (final pip in board) pip.fold<int>(0, (sum, id) => sum + _net(id)),
];

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
      expect(
        FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().turnPlayer,
        GammonPlayer.one,
      );
    });

    test('colorFor maps each player name to its color (player1=X here)', () {
      final board = FibsBoard.fromCrumbs(parse(fibsBoardLine(opening)).crumbs!);
      // helper builds xplayer=player1 (color -1 = X), oplayer=player2 (O)
      expect(board.colorFor('xplayer'), GammonPlayer.one); // X
      expect(board.colorFor('oplayer'), GammonPlayer.two); // O
      expect(board.colorFor('a-spectator'), isNull);
    });

    test('colorFor treats the literal "You" as us in our own game', () {
      // in our own game FIBS names player1 "You" regardless of our username
      final line = fibsBoardLine(opening).replaceFirst('xplayer', 'You');
      final board = FibsBoard.fromCrumbs(parse(line).crumbs!);
      expect(board.colorFor('joe_grammer'), GammonPlayer.one); // player1=X
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

    test('a real captured server frame maps to a valid 15-vs-15 board', () {
      // captured live from FIBS watching BlunderBot_IX vs cosmicrocker.
      // player1Color is 1 here (player1 is O), which exercises the color-aware
      // routing of the off/bar count fields — a flat player1=X assumption
      // produces an invalid 14/16 board.
      const frame =
          'board:BlunderBot_IX:cosmicrocker:3:1:1:0:1:4:1:0:3:1:0:0'
          ':0:0:0:0:0:0:0:0:0:0:-4:-2:-2:-1:0:0:0:-1:0:0:0:0:2:0:1:0:1:-1:0:25'
          ':5:6:0:0:2:1:0:0';
      final cm = parse(frame);
      expect(cm.cookie, FibsCookie.FIBS_Board);
      final board = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().board;

      var x = 0;
      var o = 0;
      for (final pip in board) {
        for (final id in pip) {
          if (GammonRules.playerFor(id) == GammonPlayer.one) {
            x++;
          } else {
            o++;
          }
        }
      }
      expect(x, 15, reason: 'X (player1, negative) checkers');
      expect(o, 15, reason: 'O (player2, positive) checkers');
    });

    test('borne-off counts land in the off trays', () {
      final cm = parse(fibsBoardLine(opening, xOff: 3, oOff: 2));
      final board = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState().board;

      // player1 (X) off is index 0; player2 (O) home/off is index 25
      expect(countOn(board, 0, GammonPlayer.one), 3);
      expect(countOn(board, 25, GammonPlayer.two), 2);
    });
  });

  group('FibsBoard.position', () {
    test('the opening maps to the standard typed Position', () {
      final board = FibsBoard.fromCrumbs(parse(fibsBoardLine(opening)).crumbs!);
      expect(board.position, Position.standard());
    });

    test('bar and off counts route to the right player (X=one, O=two)', () {
      final cm = parse(
        fibsBoardLine(opening, xBar: 1, oBar: 2, xOff: 3, oOff: 4),
      );
      final position = FibsBoard.fromCrumbs(cm.crumbs!).position;
      expect(position.barFor(GammonPlayer.one), 1); // X bar
      expect(position.barFor(GammonPlayer.two), 2); // O bar
      expect(position.offFor(GammonPlayer.one), 3); // X off
      expect(position.offFor(GammonPlayer.two), 4); // O off
    });

    test('toGammonState renders exactly the position (no checkers lost)', () {
      final cm = parse(fibsBoardLine(opening, xBar: 1, oOff: 2));
      final board = FibsBoard.fromCrumbs(cm.crumbs!);
      // the rendered board collapses back to the same typed Position
      expect(Position.fromBoard(board.toGammonState().board), board.position);
    });
  });

  group('FibsBoard.viewerState (you are always the bottom player)', () {
    // an opening seated as O (player1Color=1, direction=-1) -- mirrored, the
    // case where "you" must be flipped to play from the bottom-right home.
    String openingAsO({String turn = '1', String p1dice = '6:3'}) =>
        'board:You:bot:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0'
        ':0:0:2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

    test('you (O) become engine player one, moving toward your 1-point', () {
      final fb = FibsBoard.fromCrumbs(parse(openingAsO()).crumbs!);
      final me = fb.colorFor('You'); // O == player two in the raw frame
      expect(me, GammonPlayer.two);

      final gs = fb.viewerState(me: me!);
      // it is our turn, and in the viewer frame WE are player one
      expect(gs.turnPlayer, GammonPlayer.one);
      // every legal move heads home (toward pip 1), never up toward 24
      final byPip = gs.getAllLegalMoves();
      expect(byPip.keys.toSet(), {24, 13, 8, 6});
      for (final moves in byPip.values) {
        for (final m in moves) {
          expect(m.toPipNo, lessThan(m.fromPipNo), reason: 'moves go home');
        }
      }
    });

    test('an X game is unchanged (you are already player one)', () {
      final fb = FibsBoard.fromCrumbs(parse(fibsBoardLine(opening)).crumbs!);
      final me = fb.colorFor('xplayer'); // player1Color=-1 -> X == player one
      expect(me, GammonPlayer.one);
      expect(
        Position.fromBoard(fb.viewerState(me: me!).board),
        Position.fromBoard(fb.toGammonState().board),
      );
    });

    test('an O bear-off bears off toward the bottom-right off tray', () {
      // O all home on its 1..6 points (FIBS frame, positive = O), our roll 5:2
      const homeAsO = [
        0, 2, 2, 3, 3, 3, 2, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, -2, -13, 0, 0,
      ];
      final line =
          'board:You:bot:1:0:0:${homeAsO.join(':')}'
          ':1:5:2:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';
      final fb = FibsBoard.fromCrumbs(parse(line).crumbs!);
      final gs = fb.viewerState(me: fb.colorFor('You')!);
      // bearing off lands on player one's off tray (engine pip 0, lower-right)
      final off = gs
          .getAllLegalMoves()
          .values
          .expand((m) => m)
          .any((m) => m.toPipNo == GammonRules.offPipNoFor(GammonPlayer.one));
      expect(off, isTrue, reason: 'an O home position can bear off to pip 0');
    });
  });
}
