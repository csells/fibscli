import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trotter/trotter.dart';
import 'package:dartx/dartx.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  var points = GammonRules.initialPoints();
  var hits = [0, 0]; // Checkers hit per player
  var dice = [0, 0]; // Dice roll
  var sideSign = 1; // Either -1, or 1, or 0 if no game is playing
  var turnCount = 0;
  int selectedIndex = -1; // -1 if no selection.

  void _rollDice() {
    print('_rollDice()');
    dice[0] = _rand.nextInt(6) + 1;
    dice[1] = _rand.nextInt(6) + 1;
    notifyListeners();
  }

  void nextTurn() {
    sideSign = -sideSign;
    turnCount++;
    _rollDice();
  }

  void doMoveOrHit({int fromPip, int toPip}) {
    assert(fromPip >= 1 && fromPip <= 24);
    assert(toPip >= 1 && toPip <= 24);

    final fromIndex = fromPip - 1;
    final toIndex = toPip - 1;
    if (GammonRules.canMove(fromIndex, toIndex, points)) {
      GammonRules.doMove(fromIndex, toIndex, points);
    } else if (GammonRules.canHit(fromIndex, toIndex, points)) {
      GammonRules.doHit(fromIndex, toIndex, points, hits);
    }
  }

  Iterable<GammonMove> getLegalMoves(int fromStartPip) sync* {
    // are there pieces on this pip?
    final point = points[fromStartPip - 1];
    if (point == 0) return;

    // do the pieces belong to the current player?
    if ((point < 1 ? -1 : 1) != sideSign) return;

    // check all components of the dice for legal moves, taking into account doubles
    final rolls = [...dice, if (dice[0] == dice[1]) ...dice];

    // need to uniqify the numbers for trotter
    final stringRolls = [for (var i = 0; i != rolls.length; ++i) '${rolls[i]}${String.fromCharCode(97 + i)}'];
    final comps = Compounds(stringRolls);

    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to be legal
      final hops = [for (final c in comp) int.parse(c.substring(0, 1)) * sideSign];
      final toEndPip = fromStartPip + hops.sum();
      if (toEndPip >= 1 && toEndPip <= 24) {
        final move = GammonMove(fromPip: fromStartPip, toPip: toEndPip, hops: hops);
        if (legalMove(move)) yield move;
      }
    }
  }

  bool legalMove(GammonMove move) {
    // temp board state while checking each hop of the move
    final movePoints = List<int>.from(points);
    final moveHits = List<int>.from(hits);

    // only a legal move if each hop is legal
    var fromPip = move.fromPip;
    for (final hop in move.hops) {
      final toPip = fromPip + hop;
      final fromIndex = fromPip - 1;
      final toIndex = toPip - 1;

      // check this hop and update temp game state for next hop
      if (GammonRules.canMove(fromIndex, toIndex, movePoints)) {
        GammonRules.doMove(fromIndex, toIndex, movePoints);
      } else if (GammonRules.canHit(fromIndex, toIndex, movePoints)) {
        GammonRules.doHit(fromIndex, toIndex, movePoints, moveHits);
      } else {
        return false;
      }

      fromPip = toPip;
    }

    return true;
  }
}

extension GammonMoves on Iterable<GammonMove> {
  List<int> hops({int fromPip, int toPip}) =>
      this.firstOrNullWhere((m) => m.fromPip == fromPip && m.toPip == toPip)?.hops;

  bool hasHops({int fromPip, int toPip}) => hops(fromPip: fromPip, toPip: toPip) != null;
}

class GammonMove {
  final int fromPip;
  final int toPip;
  final List<int> hops;
  GammonMove({@required this.fromPip, @required this.toPip, @required this.hops})
      : assert(fromPip != null && fromPip >= 1 && fromPip <= 25),
        assert(toPip != null && toPip >= 1 && toPip <= 24),
        assert(hops != null && hops.isNotEmpty);

  @override
  String toString() => 'GammonMove(fromPip: $fromPip, toPip: $toPip, hops: $hops)';

  @override
  bool operator ==(Object o) =>
      (identical(this, o)) || o is GammonMove && o.fromPip == fromPip && o.toPip == toPip && listEquals(o.hops, hops);

  @override
  int get hashCode {
    var hash = fromPip.hashCode ^ toPip.hashCode;
    for (final hop in hops) hash ^= hop.hashCode;
    return hash;
  }
}

class GammonRules {
  // The total number of points on the table.
  static const numPoints = 24;

  // The initial position tuples - [index, count]
  static const initialPointTuples = const [
    [0, 2],
    [11, 5],
    [16, 3],
    [18, 5]
  ];

  static List<int> initialPoints() {
    var points = List<int>.filled(numPoints, 0);
    for (var indexCount in initialPointTuples) {
      var pointIndex = indexCount[0];
      var checkerCount = indexCount[1];

      // White checkers are positive.
      points[pointIndex] = checkerCount;

      // Black checkers are negative, placed mirrorwise.
      points[numPoints - pointIndex - 1] = -checkerCount;
    }
    return points;
  }

  // Returns true if a checker can be moved, without hitting.
  static bool canMove(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[toIndex] == 0) return true;
    return points[fromIndex].sign == points[toIndex].sign;
  }

  // Returns true, if a piece can be hit, and taken out.
  static bool canHit(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[fromIndex].sign == points[toIndex].sign) return false;
    return points[toIndex].abs() == 1;
  }

  // Moves a checker without hitting.
  static void doMove(int fromIndex, int toIndex, final List<int> points) {
    assert(canMove(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign * (points[toIndex].abs() + 1);
  }

  // Hits a lone checker.
  static void doHit(int fromIndex, int toIndex, final List<int> points, List<int> hits) {
    assert(canHit(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign;
  }

  static int sideIndex(int sideSign /* -1 or 1 */) {
    assert(sideSign.abs() == 1);
    return (sideSign + 1) >> 1;
  }

  // Returns true if the player has any hit checkers, false otherwise.
  static bool hasHit(int sideSign, final List<int> hits) {
    return hits[sideIndex(sideSign)] != 0;
  }

  // Adds a hit checker.
  static void addHit(int sideSign, final List<int> hits) {
    hits[sideIndex(sideSign)]++;
  }

  // Remove a hit checker.
  static void removeHit(int sideSign, List<int> hits) {
    hits[sideIndex(sideSign)]--;
  }
}
