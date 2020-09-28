import 'dart:math';
import 'package:fibscli/dice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trotter/trotter.dart';
import 'package:dartx/dartx.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  // index: 1-24 == board, 0 == bar, 25 == home
  // value: list of piece ids, <0 == player1, >0 == player2
  final _pips = List<List<int>>(26);

  final _dice = <DieState>[]; // dice rolls and whether they're still available
  int _turnSign; // -1: player1, 1: player2
  GammonState _undoState; // state for implementing undo

  GammonState() {
    _reset();
  }

  void _setState({
    @required List<List<int>> pips,
    @required List<DieState> dice,
    @required int turnSign,
  }) {
    for (var i = 0; i < pips.length; ++i) _pips[i] = List.from(pips[i]);

    _dice.clear();
    _dice.addAll(dice.map((d) => DieState(d.roll)).toList());

    _turnSign = turnSign;
  }

  void _reset() {
    _setState(pips: GammonRules.initialPips(), dice: <DieState>[], turnSign: 1);
  }

  GammonState.clone(GammonState state) {
    _setState(pips: state._pips, dice: state._dice, turnSign: state._turnSign);
  }

  List<List<int>> get pips => List.unmodifiable(_pips);
  List<DieState> get dice => List.unmodifiable(_dice);
  int get turnSign => _turnSign;

  void nextTurn() {
    _turnSign *= -1;
    _rollDice();
    _undoState = GammonState.clone(this);
  }

  void undo() {
    _setState(pips: _undoState._pips, dice: _undoState._dice, turnSign: _undoState._turnSign);
    notifyListeners();
  }

  Iterable<GammonMove> getLegalMoves(int fromStartPipNo) sync* {
    // are there pieces on this pip?
    final fromPip = _pips[fromStartPipNo];
    if (fromPip.isEmpty) return;

    // do the pieces belong to the current player?
    if (!fromPip.any((p) => p.sign == _turnSign)) return;

    // check all components of the _dice for legal moves, taking into account doubles
    // need to uniqify the numbers for trotter
    final availableDice = _dice.where((d) => d.available).toList();
    final stringRolls = [
      for (var i = 0; i != availableDice.length; ++i) '${availableDice[i].roll}${String.fromCharCode(97 + i)}'
    ];

    final comps = Compounds(stringRolls);
    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to be legal
      final hops = [for (final c in comp) int.parse(c.substring(0, 1)) * _turnSign];
      final toEndPipNo = fromStartPipNo + hops.sum();
      if (toEndPipNo >= 0 && toEndPipNo <= 25) {
        final move = GammonMove(sign: _turnSign, fromPipNo: fromStartPipNo, toPipNo: toEndPipNo, hops: hops);
        if (_legalMove(move)) yield move;
      }
    }
  }

  void doMoveOrHit({@required int fromPipNo, @required int toPipNo}) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);

    if (GammonRules.canMove(_turnSign, fromPipNo, toPipNo, pips)) {
      GammonRules.doMove(_turnSign, fromPipNo, toPipNo, pips);
    } else if (GammonRules.canHit(_turnSign, fromPipNo, toPipNo, pips)) {
      GammonRules.doHit(_turnSign, fromPipNo, toPipNo, pips);
    } else {
      return;
    }

    _useDie((fromPipNo - toPipNo).abs());
    notifyListeners();
  }

  int pipCount({@required int sign}) {
    var pipCount = 0;

    // pips left on the board
    for (var i = 1; i <= 24; ++i) {
      final pip = _pips[i];
      if (pip.isEmpty) continue;
      if (pip[0].sign != sign) continue;
      final pieceCount = pip.length;
      pipCount += sign == -1 ? -pieceCount * i : pieceCount * (23 - i);
    }

    // pips left on the bar
    pipCount += _pips[25].where((p) => p.sign == sign).sum() * 24;

    return pipCount;
  }

  void _useDie(int roll) {
    _dice.firstWhere((d) => d.roll == roll && d.available).available = false;
    _disableUnusableDice();
  }

  bool _legalMove(GammonMove move) {
    // temp board state while checking each hop of the move
    final movePips = List<List<int>>(26);
    for (var i = 0; i < _pips.length; ++i) movePips[i] = List.from(_pips[i]);

    // only a legal move if each hop is legal
    var fromPipNo = move.fromPipNo;
    for (final hop in move.hops) {
      final toPipNo = fromPipNo + hop;

      // check this hop and update temp game state for next hop
      if (GammonRules.canMove(move.sign, fromPipNo, toPipNo, movePips)) {
        GammonRules.doMove(move.sign, fromPipNo, toPipNo, movePips);
      } else if (GammonRules.canHit(move.sign, fromPipNo, toPipNo, movePips)) {
        GammonRules.doHit(move.sign, fromPipNo, toPipNo, movePips);
      } else {
        return false;
      }

      fromPipNo = toPipNo;
    }

    return true;
  }

  void _rollDice() {
    final roll1 = _rand.nextInt(6) + 1;
    final roll2 = _rand.nextInt(6) + 1;
    final rolls = [
      roll1,
      roll2,
      if (roll1 == roll2) ...[roll1, roll1]
    ];

    _dice.clear();
    _dice.addAll([for (var roll in rolls) DieState(roll)]);
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
}

extension GammonMoves on Iterable<GammonMove> {
  List<int> hops({int fromPipNo, int toPipNo}) =>
      this.firstOrNullWhere((m) => m.fromPipNo == fromPipNo && m.toPipNo == toPipNo)?.hops;

  bool hasHops({int fromPipNo, int toPipNo}) => hops(fromPipNo: fromPipNo, toPipNo: toPipNo) != null;
}

class GammonMove {
  final int sign;
  final int fromPipNo;
  final int toPipNo;
  final List<int> hops;
  GammonMove({@required this.sign, @required this.fromPipNo, @required this.toPipNo, @required this.hops})
      : assert(sign == -1 || sign == 1),
        assert(fromPipNo != null && fromPipNo >= 0 && fromPipNo <= 25),
        assert(toPipNo != null && toPipNo >= 0 && toPipNo <= 25),
        assert(hops != null && hops.isNotEmpty);

  @override
  String toString() => 'GammonMove(fromPipNo: $fromPipNo, toPipNo: $toPipNo, hops: $hops)';

  @override
  bool operator ==(Object o) =>
      (identical(this, o)) ||
      o is GammonMove && o.sign == sign && o.fromPipNo == fromPipNo && o.toPipNo == toPipNo && listEquals(o.hops, hops);

  @override
  int get hashCode {
    var hash = fromPipNo.hashCode ^ toPipNo.hashCode;
    for (final hop in hops) hash ^= hop.hashCode;
    return hash;
  }
}

class GammonRules {
  static List<List<int>> initialPips() => <List<int>>[
        [], // 0: bar
        [1, 2], // 1: 2x whites
        [], // 2
        [], // 3
        [], // 4
        [], // 5
        [-11, -12, -13, -14, -15], // 6: 5x blacks
        [], // 7
        [-8, -9, -10], // 8: 3x blacks
        [], // 9
        [], // 10
        [], // 11
        [3, 4, 5, 6, 7], // 12: 5x whites
        [-3, -4, -5, -6, -7], // 13: 5x blacks
        [], // 14
        [], // 15
        [], // 16
        [8, 9, 10], // 17: 3x whites
        [], // 18
        [11, 12, 13, 14, 15], // 19: 5x whites
        [], // 20
        [], // 21
        [], // 22
        [], // 23
        [-1, -2], // 24: 2x blacks
        [], // 25: home
      ];

  // can the piece can be moved without hitting?
  static bool canMove(int sign, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);
    if (fromPipNo == 25) return false; // home
    if (toPipNo == 25) return true; // home
    if (toPipNo == 0) return false; // bar
    if (!pips[fromPipNo].any((p) => p.sign == sign)) return false;
    if (pips[toPipNo].isEmpty) return true;
    if (pips[toPipNo][0].sign == sign) return true;
    return false;
  }

  // move the piece without hitting
  static void doMove(int sign, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(canMove(sign, fromPipNo, toPipNo, pips));
    final fromPieces = pips[fromPipNo];
    final index = fromPieces.lastIndexWhere((p) => p.sign == sign);
    final id = fromPieces.removeAt(index);
    final toPieces = pips[toPipNo];
    toPieces.add(id);
  }

  // can the piece can be hit?
  static bool canHit(int sign, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);
    if (fromPipNo == 25) return false; // home
    if (toPipNo == 25) return false; // home
    if (toPipNo == 0) return false; // bar
    if (!pips[fromPipNo].any((p) => p.sign == sign)) return false;
    if (pips[toPipNo].length != 1) return false;
    if (pips[toPipNo][0].sign != sign) return true;
    return false;
  }

  // Hits a lone piece
  static void doHit(int sign, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(canHit(sign, fromPipNo, toPipNo, pips));
    final fromPieces = pips[fromPipNo];
    final fromIndex = fromPieces.lastIndexWhere((p) => p.sign == sign);
    final fromId = fromPieces.removeAt(fromIndex);
    final toPieces = pips[toPipNo];
    final toIndex = toPieces.lastIndexWhere((p) => p.sign != sign);
    final toId = toPieces.removeAt(toIndex);
    toPieces.add(fromId);
    pips[0].add(toId); // bar
  }
}
