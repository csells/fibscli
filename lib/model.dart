import 'dart:math';
import 'package:fibscli/dice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trotter/trotter.dart';
import 'package:dartx/dartx.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  // index: 1-24 == board, 0 == player1 home, player2 bar, 25 == player1 bar, player2 home
  // value: list of piece ids, <0 == player1, >0 == player2
  final _pips = List<List<int>>(26);

  final _dice = <DieState>[]; // dice rolls and whether they're still available
  Player _turnPlayer;
  GammonState _undoState; // state for implementing undo

  GammonState() {
    _setState(pips: GammonRules.initialPips(), dice: <DieState>[], turnPlayer: Player.two);
  }

  void _setState({
    @required List<List<int>> pips,
    @required List<DieState> dice,
    @required Player turnPlayer,
  }) {
    for (var i = 0; i < pips.length; ++i) _pips[i] = List.from(pips[i]);

    _dice.clear();
    _dice.addAll(dice.map((d) => DieState(d.roll)).toList());

    _turnPlayer = turnPlayer;
  }

  GammonState.from(GammonState state) {
    _setState(pips: state._pips, dice: state._dice, turnPlayer: state._turnPlayer);
  }

  List<List<int>> get pips => List.unmodifiable(_pips);
  List<DieState> get dice => List.unmodifiable(_dice);
  Player get turnPlayer => _turnPlayer;

  void nextTurn() {
    _turnPlayer = GammonRules.otherPlayer(_turnPlayer);
    _rollDice();
    _undoState = GammonState.from(this);
  }

  void undo() {
    _setState(pips: _undoState._pips, dice: _undoState._dice, turnPlayer: _undoState._turnPlayer);
    notifyListeners();
  }

  Iterable<GammonMove> getLegalMoves(int fromStartPipNo) sync* {
    // are there pieces on this pip?
    final fromPip = _pips[fromStartPipNo];
    if (fromPip.isEmpty) return;

    // do the pieces belong to the current player?
    final sign = GammonRules.signFor(_turnPlayer);
    if (!fromPip.any((p) => p.sign == sign)) return;

    // check all components of the _dice for legal moves, taking into account doubles
    // need to uniqify the numbers for trotter
    final availableDice = _dice.where((d) => d.available).toList();
    final stringRolls = [
      for (var i = 0; i != availableDice.length; ++i) '${availableDice[i].roll}${String.fromCharCode(97 + i)}'
    ];

    final comps = Compounds(stringRolls);
    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to be legal
      final hops = [for (final c in comp) int.parse(c.substring(0, 1)) * sign];
      final toEndPipNo = fromStartPipNo + hops.sum();
      if (toEndPipNo >= 0 && toEndPipNo <= 25) {
        final move = GammonMove(player: _turnPlayer, fromPipNo: fromStartPipNo, toPipNo: toEndPipNo, hops: hops);
        if (_legalMove(move)) yield move;
      }
    }
  }

  void doMoveOrHit({@required int fromPipNo, @required int toPipNo}) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);

    if (GammonRules.canMove(_turnPlayer, fromPipNo, toPipNo, pips)) {
      GammonRules.doMove(_turnPlayer, fromPipNo, toPipNo, pips);
    } else if (GammonRules.canHit(_turnPlayer, fromPipNo, toPipNo, pips)) {
      GammonRules.doHit(_turnPlayer, fromPipNo, toPipNo, pips);
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
      pipCount += sign == -1 ? pieceCount * i : pieceCount * (25 - i);
    }

    // pips left on the bar
    pipCount += _pips[0].where((p) => p.sign == sign).length * 24;

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
      if (GammonRules.canMove(move.player, fromPipNo, toPipNo, movePips)) {
        GammonRules.doMove(move.player, fromPipNo, toPipNo, movePips);
      } else if (GammonRules.canHit(move.player, fromPipNo, toPipNo, movePips)) {
        GammonRules.doHit(move.player, fromPipNo, toPipNo, movePips);
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

enum Player { one, two }

class GammonMove {
  final Player player;
  final int fromPipNo;
  final int toPipNo;
  final List<int> hops;
  GammonMove({@required this.player, @required this.fromPipNo, @required this.toPipNo, @required this.hops})
      : assert(player != null),
        assert(fromPipNo != null && fromPipNo >= 0 && fromPipNo <= 25),
        assert(toPipNo != null && toPipNo >= 0 && toPipNo <= 25),
        assert(hops != null && hops.isNotEmpty);

  @override
  String toString() => 'GammonMove(player: $player, fromPipNo: $fromPipNo, toPipNo: $toPipNo, hops: $hops)';

  @override
  bool operator ==(Object o) =>
      (identical(this, o)) ||
      o is GammonMove &&
          o.player == player &&
          o.fromPipNo == fromPipNo &&
          o.toPipNo == toPipNo &&
          listEquals(o.hops, hops);

  @override
  int get hashCode {
    var hash = player.hashCode ^ fromPipNo.hashCode ^ toPipNo.hashCode;
    for (final hop in hops) hash ^= hop.hashCode;
    return hash;
  }
}

class GammonRules {
  static List<List<int>> initialPips() => <List<int>>[
        [], // 0: player1 home, player2 bar
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
        [], // 25: player1 bar, player2 home
      ];

  static int signFor(Player player) => player == Player.one ? -1 : 1;
  static int homeFor(Player player) => player == Player.one ? 0 : 25;
  static int barFor(Player player) => player == Player.one ? 25 : 0;
  static Player otherPlayer(Player player) => player == Player.one ? Player.two : Player.one;

  // can the piece can be moved without hitting?
  static bool canMove(Player player, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);
    if (fromPipNo == homeFor(player)) return false; // home
    if (toPipNo == homeFor(player)) return false; // home
    if (toPipNo == barFor(player)) return false; // bar

    final sign = signFor(player);
    if (!pips[fromPipNo].any((p) => p.sign == sign)) return false;
    if (pips[toPipNo].isEmpty) return true;
    if (pips[toPipNo][0].sign == sign) return true;
    return false;
  }

  // move the piece without hitting
  static void doMove(Player player, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(canMove(player, fromPipNo, toPipNo, pips));
    final fromPieces = pips[fromPipNo];
    final sign = signFor(player);
    final index = fromPieces.lastIndexWhere((p) => p.sign == sign);
    final id = fromPieces.removeAt(index);
    final toPieces = pips[toPipNo];
    toPieces.add(id);
  }

  // can the piece can be hit?
  static bool canHit(Player player, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(fromPipNo >= 0 && fromPipNo <= 25);
    assert(toPipNo >= 0 && toPipNo <= 25);

    final home = homeFor(player);
    final bar = barFor(player);
    if (fromPipNo == home) return false; // home
    if (toPipNo == home) return false; // home
    if (toPipNo == bar) return false; // bar

    final sign = signFor(player);
    if (!pips[fromPipNo].any((p) => p.sign == sign)) return false;
    if (pips[toPipNo].length != 1) return false;
    if (pips[toPipNo][0].sign != sign) return true;
    return false;
  }

  // Hits a lone piece
  static void doHit(Player player, int fromPipNo, int toPipNo, List<List<int>> pips) {
    assert(canHit(player, fromPipNo, toPipNo, pips));
    final fromPieces = pips[fromPipNo];
    final sign = signFor(player);
    final fromIndex = fromPieces.lastIndexWhere((p) => p.sign == sign);
    final fromId = fromPieces.removeAt(fromIndex);
    final toPieces = pips[toPipNo];
    final toIndex = toPieces.lastIndexWhere((p) => p.sign != sign);
    final toId = toPieces.removeAt(toIndex);
    toPieces.add(fromId);
    final bar = barFor(otherPlayer(player));
    pips[bar].add(toId); // bar
  }

  static bool canBareOff(Player player, int fromPipNo, List<List<int>> pips) {
    // TODO: canBareOff
    return false;
  }

  static void doBareOff(Player player, int fromPipNo, List<List<int>> pips) {
    // TODO: doBareOff
    assert(canBareOff(player, fromPipNo, pips));
  }
}
