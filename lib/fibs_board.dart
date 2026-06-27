import 'dice.dart';
import 'model.dart';

// A parsed FIBS boardstyle-3 `board:` snapshot, mapped into the game model so
// the existing board widgets can render a live (watched) FIBS game read-only.
//
// FIBS frame (per the FIBS Client Protocol spec): the board array has 26 cells;
// cells 1..24 are the points, positive counts are O's checkers and negative are
// X's. This lines up exactly with the engine's own convention (player2 == O ==
// positive ids moving 1->24 and bearing off at 25; player1 == X == negative ids
// moving 24->1 and bearing off at 0), so the points map by identity. Bar and
// borne-off counts come from the dedicated FIBS fields, not the board cells.
// `color`/`direction` only orient a player's own display and don't change how
// the cell values are read, so they're ignored here.
class FibsBoard {
  FibsBoard({
    required this.points,
    required this.turnColor,
    required this.xDice,
    required this.oDice,
    required this.cube,
    required this.xOff,
    required this.oOff,
    required this.xBar,
    required this.oBar,
  });

  factory FibsBoard.fromCrumbs(Map<String, String> crumbs) {
    List<int> dice(String key) =>
        crumbs[key]!.split(':').map(int.parse).toList();
    return FibsBoard(
      points: crumbs['board']!.split(':').map(int.parse).toList(),
      turnColor: int.parse(crumbs['turnColor']!),
      xDice: dice('player1Dice'),
      oDice: dice('player2Dice'),
      cube: int.parse(crumbs['doublingCube']!),
      xOff: int.parse(crumbs['player1Home']!),
      oOff: int.parse(crumbs['player2Home']!),
      xBar: int.parse(crumbs['player1Bar']!),
      oBar: int.parse(crumbs['player2Bar']!),
    );
  }

  final List<int> points; // 26 cells, FIBS frame (positive = O, negative = X)
  final int turnColor; // -1 X to move, 1 O to move, 0 game over
  final List<int> xDice; // player1 (X) dice
  final List<int> oDice; // player2 (O) dice
  final int cube;
  final int xOff; // X checkers borne off
  final int oOff; // O checkers borne off
  final int xBar; // X checkers on the bar
  final int oBar; // O checkers on the bar

  GammonPlayer? get turnPlayer => turnColor == -1
      ? GammonPlayer.one
      : turnColor == 1
          ? GammonPlayer.two
          : null;

  // the dice of whoever is on roll (empty until someone has rolled)
  List<int> get activeDice {
    final dice = turnColor == -1 ? xDice : oDice;
    return dice.any((d) => d == 0) ? const [] : dice;
  }

  GammonState toGammonState() {
    // synthesize stable signed piece ids per player (negative = X = player1)
    var nextX = 0;
    var nextO = 0;
    int xId() {
      nextX += 1;
      return -nextX;
    }

    int oId() => ++nextO;

    final board = List<List<int>>.generate(26, (_) => <int>[]);

    void place(int pip, int count) {
      if (count == 0) return;
      final ids = count < 0 ? xId : oId;
      for (var i = 0; i != count.abs(); ++i) {
        board[pip].add(ids());
      }
    }

    // points 1..24 map by identity (sign and index)
    for (var pip = 1; pip <= 24; ++pip) {
      place(pip, points[pip]);
    }

    // bars: X bar at index 25 (player1 bar), O bar at index 0 (player2 bar)
    place(25, -xBar);
    place(0, oBar);

    // borne off: X off at index 0 (player1 off), O home/off at index 25
    place(0, -xOff);
    place(25, oOff);

    final dice = activeDice.map(DieState.new).toList();
    return GammonState.from(
      board: board,
      dice: dice,
      turnPlayer: turnPlayer,
    );
  }
}
