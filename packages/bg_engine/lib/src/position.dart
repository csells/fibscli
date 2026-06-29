import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'rules.dart';

/// A typed, immutable backgammon position — the checker layout only (dice, turn
/// and cube live in `BgPosition`, which wraps this).
///
/// Unlike the engine's `List<List<int>>` board (where "negative id = player
/// one", and indices 0/25 secretly mean off/bar), this makes the structure
/// explicit and illegal states unrepresentable: a point is owned by at most one
/// player (a single signed count), counts are bounded, and bar/off are named
/// per player. Conversions to/from the engine board are total, so the rules
/// engine keeps working unchanged while everything new speaks [Position].
@immutable
class Position {
  /// Creates a position from 24 signed point counts (index 0 = point 1 …
  /// index 23 = point 24; negative = player one, positive = player two) plus
  /// the bar/off counts per player.
  Position({
    required List<int> points,
    this.oneBar = 0,
    this.twoBar = 0,
    this.oneOff = 0,
    this.twoOff = 0,
  }) : assert(points.length == 24, 'a board has 24 points'),
       assert(
         points.every((c) => c.abs() <= 15),
         'a point holds 0..15 checkers of a single owner',
       ),
       assert(oneBar >= 0 && twoBar >= 0 && oneOff >= 0 && twoOff >= 0),
       points = List<int>.unmodifiable(points);

  /// The standard opening position.
  factory Position.standard() => Position.fromBoard(GammonRules.initialBoard());

  /// Read a [Position] from the engine's canonical board (index 0 = player1
  /// off / player2 bar; 1..24 = points; 25 = player1 bar / player2 off).
  factory Position.fromBoard(List<List<int>> board) {
    int countOf(int pip, GammonPlayer player) =>
        board[pip].where((id) => GammonRules.playerFor(id) == player).length;

    final points = List<int>.filled(24, 0);
    for (var pip = 1; pip <= 24; pip++) {
      // single-owner: at most one of these is non-zero
      points[pip - 1] =
          countOf(pip, GammonPlayer.two) - countOf(pip, GammonPlayer.one);
    }
    return Position(
      points: points,
      oneBar: countOf(25, GammonPlayer.one),
      twoBar: countOf(0, GammonPlayer.two),
      oneOff: countOf(0, GammonPlayer.one),
      twoOff: countOf(25, GammonPlayer.two),
    );
  }

  /// Signed checker count per point (index 0 = point 1; - = player one,
  /// + = player two).
  final List<int> points;

  /// Player one's checkers on the bar.
  final int oneBar;

  /// Player two's checkers on the bar.
  final int twoBar;

  /// Player one's borne-off checkers.
  final int oneOff;

  /// Player two's borne-off checkers.
  final int twoOff;

  /// The number of [player] checkers on [point] (1..24).
  int countAt({required int point, required GammonPlayer player}) {
    final signed = points[point - 1];
    if (player == GammonPlayer.one) return signed < 0 ? -signed : 0;
    return signed > 0 ? signed : 0;
  }

  /// [player]'s checkers on the bar.
  int barFor(GammonPlayer player) =>
      player == GammonPlayer.one ? oneBar : twoBar;

  /// [player]'s borne-off checkers.
  int offFor(GammonPlayer player) =>
      player == GammonPlayer.one ? oneOff : twoOff;

  /// All 15 (in a legal game) of [player]'s checkers: points + bar + off.
  int totalFor(GammonPlayer player) {
    var total = barFor(player) + offFor(player);
    for (var point = 1; point <= 24; point++) {
      total += countAt(point: point, player: player);
    }
    return total;
  }

  /// Render back to the engine's canonical board, synthesising stable signed
  /// piece ids (negative = player one, positive = player two).
  List<List<int>> toBoard() {
    final board = List<List<int>>.generate(26, (_) => <int>[]);
    var nextOne = 0;
    var nextTwo = 0;
    void place(int pip, GammonPlayer player, int count) {
      for (var i = 0; i < count; i++) {
        board[pip].add(player == GammonPlayer.one ? -++nextOne : ++nextTwo);
      }
    }

    for (var point = 1; point <= 24; point++) {
      final signed = points[point - 1];
      if (signed < 0) place(point, GammonPlayer.one, -signed);
      if (signed > 0) place(point, GammonPlayer.two, signed);
    }
    place(25, GammonPlayer.one, oneBar); // player1 bar
    place(0, GammonPlayer.two, twoBar); // player2 bar
    place(0, GammonPlayer.one, oneOff); // player1 off
    place(25, GammonPlayer.two, twoOff); // player2 off
    return board;
  }

  @override
  bool operator ==(Object other) =>
      other is Position &&
      const ListEquality<int>().equals(other.points, points) &&
      other.oneBar == oneBar &&
      other.twoBar == twoBar &&
      other.oneOff == oneOff &&
      other.twoOff == twoOff;

  @override
  int get hashCode => Object.hash(
    const ListEquality<int>().hash(points),
    oneBar,
    twoBar,
    oneOff,
    twoOff,
  );

  @override
  String toString() =>
      'Position(points: $points, bar: $oneBar/$twoBar, off: $oneOff/$twoOff)';
}
