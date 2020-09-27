import 'dart:math';
import 'package:fibscli/dice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trotter/trotter.dart';
import 'package:dartx/dartx.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  final List<int> points;
  final List<int> _hits; // pieces per player on the bar
  final List<int> _homes; // pieces per player in the home
  List<DieState> _dice; // dice rolls and whether they're still available
  int _sideSign; // either -1, or 1, or 0 if no game is playing
  GammonState _undoState;

  GammonState()
      : points = GammonRules.initialPoints(),
        _hits = [0, 0],
        _homes = [0, 0],
        _sideSign = 1;

  GammonState.clone(GammonState state)
      : points = List.from(state.points),
        _hits = List.from(state._hits),
        _homes = List.from(state._homes),
        _dice = state._dice.map((d) => DieState(d.roll)).toList(),
        _sideSign = state._sideSign;

  int get sideSign => _sideSign;
  List<DieState> get dice => List.unmodifiable(_dice);
  List<int> get hits => List.unmodifiable(_hits);
  List<int> get homes => List.unmodifiable(_homes);

  void _rollDice() {
    final roll1 = _rand.nextInt(6) + 1;
    final roll2 = _rand.nextInt(6) + 1;
    final rolls = [
      roll1,
      roll2,
      if (roll1 == roll2) ...[roll1, roll1]
    ];

    _dice = [for (var roll in rolls) DieState(roll)];
    _disableUnusableDice();

    notifyListeners();
  }

  void _disableUnusableDice() {
    // check all the pips for legal moves
    final allLegalMoves = <GammonMove>{};
    for (var fromPip = 1; fromPip <= 24; ++fromPip) allLegalMoves.addAll(getLegalMoves(fromPip));

    // find all of the possible hops
    final allHops = Set<int>.from(allLegalMoves.flatMap((m) => m.hops.map((h) => h.abs())));

    // remove dice that aren't usable
    for (final die in _dice.where((d) => d.available)) {
      if (!allHops.contains(die.roll)) die.available = false;
    }
  }

  void nextTurn() {
    _sideSign *= -1;
    _rollDice();
    _undoState = GammonState.clone(this);
  }

  void undo() {
    points.setAll(0, _undoState.points);
    _hits.setAll(0, _undoState._hits);
    _homes.setAll(0, _undoState._homes);
    _dice = _undoState._dice;
    _sideSign = _undoState._sideSign;
    notifyListeners();
  }

  void doMoveOrHit({int fromPip, int toPip}) {
    assert(fromPip >= 1 && fromPip <= 24);
    assert(toPip >= 1 && toPip <= 24);

    final fromIndex = fromPip - 1;
    final toIndex = toPip - 1;
    if (GammonRules.canMove(fromIndex, toIndex, points)) {
      GammonRules.doMove(fromIndex, toIndex, points);
    } else if (GammonRules.canHit(fromIndex, toIndex, points)) {
      GammonRules.doHit(fromIndex, toIndex, points, _hits);
    } else {
      return;
    }

    _useDie((fromPip - toPip).abs());
    notifyListeners();
  }

  void _useDie(int roll) {
    _dice.firstWhere((d) => d.roll == roll && d.available).available = false;
    _disableUnusableDice();
  }

  Iterable<GammonMove> getLegalMoves(int fromStartPip) sync* {
    // are there pieces on this pip?
    final point = points[fromStartPip - 1];
    if (point == 0) return;

    // do the pieces belong to the current player?
    if ((point < 1 ? -1 : 1) != _sideSign) return;

    // check all components of the _dice for legal moves, taking into account doubles
    // need to uniqify the numbers for trotter
    final availableDice = _dice.where((d) => d.available).toList();
    final stringRolls = [
      for (var i = 0; i != availableDice.length; ++i) '${availableDice[i].roll}${String.fromCharCode(97 + i)}'
    ];
    final comps = Compounds(stringRolls);

    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to be legal
      final hops = [for (final c in comp) int.parse(c.substring(0, 1)) * _sideSign];
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
    final moveHits = List<int>.from(_hits);

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
  static const initialPointTuples = [
    [0, 2],
    [11, 5],
    [16, 3],
    [18, 5],
  ];

  static List<int> initialPoints() {
    var points = List<int>.filled(numPoints, 0);
    for (var indexCount in initialPointTuples) {
      var pointIndex = indexCount[0];
      var pieceCount = indexCount[1];

      // White pieces are positive.
      points[pointIndex] = pieceCount;

      // Black pieces are negative, placed mirrorwise.
      points[numPoints - pointIndex - 1] = -pieceCount;
    }
    return points;
  }

  // Returns true if a piece can be moved, without hitting.
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

  // Moves a piece without hitting.
  static void doMove(int fromIndex, int toIndex, final List<int> points) {
    assert(canMove(fromIndex, toIndex, points));
    int _sideSign = points[fromIndex].sign;
    points[fromIndex] = _sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = _sideSign * (points[toIndex].abs() + 1);
  }

  // Hits a lone piece.
  static void doHit(int fromIndex, int toIndex, final List<int> points, List<int> hits) {
    assert(canHit(fromIndex, toIndex, points));
    int _sideSign = points[fromIndex].sign;
    points[fromIndex] = _sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = _sideSign;
    addHit(_sideSign, hits);
  }

  static int _sideIndex(int _sideSign) => (_sideSign + 1) >> 1;

  // Adds a hit piece
  static void addHit(int _sideSign, final List<int> hits) => hits[_sideIndex(_sideSign)]++;

  // Remove a hit piece
  static void removeHit(int _sideSign, List<int> hits) => hits[_sideIndex(_sideSign)]--;

  // Adds a home piece
  static void addHome(int _sideSign, final List<int> homes) => homes[_sideIndex(_sideSign)]++;

  // Remove a home piece
  static void removeHome(int _sideSign, List<int> homes) => homes[_sideIndex(_sideSign)]--;
}
