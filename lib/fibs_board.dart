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
    required this.player1Color,
    required this.direction,
    required this.player1Dice,
    required this.player2Dice,
    required this.cube,
    required this.player1Off,
    required this.player2Off,
    required this.player1Bar,
    required this.player2Bar,
    required this.player1Name,
    required this.player2Name,
    required this.canMove,
  });

  factory FibsBoard.fromCrumbs(Map<String, String> crumbs) {
    List<int> dice(String key) =>
        crumbs[key]!.split(':').map(int.parse).toList();
    return FibsBoard(
      points: crumbs['board']!.split(':').map(int.parse).toList(),
      turnColor: int.parse(crumbs['turnColor']!),
      player1Color: int.parse(crumbs['player1Color']!),
      direction: int.parse(crumbs['direction']!),
      player1Dice: dice('player1Dice'),
      player2Dice: dice('player2Dice'),
      cube: int.parse(crumbs['doublingCube']!),
      player1Off: int.parse(crumbs['player1Home']!),
      player2Off: int.parse(crumbs['player2Home']!),
      player1Bar: int.parse(crumbs['player1Bar']!),
      player2Bar: int.parse(crumbs['player2Bar']!),
      player1Name: crumbs['player1']!,
      player2Name: crumbs['player2']!,
      canMove: int.parse(crumbs['canMove']!),
    );
  }

  final List<int> points; // 26 cells, FIBS frame (positive = O, negative = X)
  final int turnColor; // -1 X to move, 1 O to move, 0 game over
  final int player1Color; // -1 if player1 is X, 1 if player1 is O
  final int direction; // player1's movement: +1 plays 1->24, -1 plays 24->1

  // The frame matches the engine convention (negative=X moves toward 1, home
  // 1-6; positive=O moves toward 24, home 19-24) exactly when player1's color
  // and direction agree; otherwise the board is mirrored (pos i <-> 25-i).
  bool get isMirrored => player1Color != direction;
  final List<int> player1Dice;
  final List<int> player2Dice;
  final int cube;
  // off/bar counts are keyed to player1/player2, NOT to color, so they must be
  // routed to X or O using player1Color.
  final int player1Off;
  final int player2Off;
  final int player1Bar;
  final int player2Bar;
  final String player1Name; // the client/"you" in this board frame
  final String player2Name;
  final int canMove; // 0..4 checkers the player on roll may move

  // A copy with selected fields overridden. Used to reconcile the turn when
  // FIBS sends FIBS_YouRoll without a fresh board (e.g. after the opponent
  // dances, FIBS auto-rolls for us): the roll proves it's our turn even though
  // the last board still shows the opponent on roll.
  FibsBoard copyWith({int? turnColor}) => FibsBoard(
        points: points,
        turnColor: turnColor ?? this.turnColor,
        player1Color: player1Color,
        direction: direction,
        player1Dice: player1Dice,
        player2Dice: player2Dice,
        cube: cube,
        player1Off: player1Off,
        player2Off: player2Off,
        player1Bar: player1Bar,
        player2Bar: player2Bar,
        player1Name: player1Name,
        player2Name: player2Name,
        canMove: canMove,
      );

  // The color (and hence GammonPlayer) that [me] plays, by matching the board's
  // player names. In our OWN game FIBS names player1 the literal "You"; when
  // watching it's the real player name (and we match neither -> null).
  GammonPlayer? colorFor(String me) {
    if (player1Name == 'You' || player1Name == me) {
      return player1Color == -1 ? GammonPlayer.one : GammonPlayer.two;
    }
    if (player2Name == 'You' || player2Name == me) {
      // player2 is the opposite color of player1
      return player1Color == -1 ? GammonPlayer.two : GammonPlayer.one;
    }
    return null; // we're only watching, not playing
  }

  bool get _player1IsX => player1Color == -1;

  int get xOff => _player1IsX ? player1Off : player2Off;
  int get oOff => _player1IsX ? player2Off : player1Off;
  int get xBar => _player1IsX ? player1Bar : player2Bar;
  int get oBar => _player1IsX ? player2Bar : player1Bar;

  GammonPlayer? get turnPlayer => turnColor == -1
      ? GammonPlayer.one // X
      : turnColor == 1
          ? GammonPlayer.two // O
          : null;

  // the dice of whoever is on roll (the player whose color == turnColor),
  // empty until someone has rolled
  List<int> get activeDice {
    final dice = turnColor == player1Color ? player1Dice : player2Dice;
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
