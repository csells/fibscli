import 'dart:math';
import 'package:fibscli/dice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trotter/trotter.dart';
import 'package:dartx/dartx.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  // index: 1-24 == board, 0 == player1 home/player2 bar, 25 == player1 bar/player2 home
  // value: list of piece ids, <0 == player1, >0 == player2
  final _board = List<List<int>>.filled(26, List<int>.empty());

  final _dice = <DieState>[]; // dice rolls and whether they're still available
  Player _turnPlayer;
  GammonState _undoState; // state for implementing undo

  GammonState() {
    _setState(board: GammonRules.initialBoard(), dice: <DieState>[], turnPlayer: Player.two);
  }

  void _setState({
    @required List<List<int>> board,
    @required List<DieState> dice,
    @required Player turnPlayer,
  }) {
    for (var i = 0; i < board.length; ++i) _board[i] = List.from(board[i]);

    _dice.clear();
    _dice.addAll(dice.map((d) => DieState(d.roll)).toList());

    _turnPlayer = turnPlayer;
  }

  GammonState.from(GammonState state) {
    _setState(board: state._board, dice: state._dice, turnPlayer: state._turnPlayer);
  }

  List<List<int>> get board => List.unmodifiable(_board);
  List<DieState> get dice => List.unmodifiable(_dice);
  Player get turnPlayer => _turnPlayer;

  void nextTurn() {
    _turnPlayer = GammonRules.otherPlayer(_turnPlayer);
    _rollDice();
    _undoState = GammonState.from(this);
  }

  void undo() {
    _setState(board: _undoState._board, dice: _undoState._dice, turnPlayer: _undoState._turnPlayer);
    notifyListeners();
  }

  Map<int, List<GammonMove>> getAllLegalMoves() {
    final rolls = _dice.where((d) => d.available).map((d) => d.roll).toList();
    return GammonRules.getAllLegalMoves(board, _turnPlayer, rolls);
  }

  List<List<GammonDelta>> applyMove({@required GammonMove move}) {
    assert(move != null);
    final deltas = GammonRules.applyMove(board, move);

    if (deltas.isNotEmpty) {
      for (final hop in move.hops) _useDie(hop.abs());
      notifyListeners();
    }

    return deltas;
  }

  int pipCount({@required int sign}) {
    var pipCount = 0;

    // pips left on the board
    for (var i = 1; i <= 24; ++i) {
      final pip = _board[i];
      if (pip.isEmpty) continue;
      if (pip[0].sign != sign) continue;
      final pieceCount = pip.length;
      pipCount += sign == -1 ? pieceCount * i : pieceCount * (25 - i);
    }

    // pips left on the bar
    pipCount += _board[0].where((p) => p.sign == sign).length * 24;

    return pipCount;
  }

  void _useDie(int roll) {
    _dice.firstWhere((d) => d.roll == roll && d.available).available = false;
    _disableUnusableDice();
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
    final rolls = _dice.where((d) => d.available).map((d) => d.roll).toList();
    final moves = GammonRules.getAllLegalMoves(board, _turnPlayer, rolls);

    // find all of the possible hops
    final hops = [
      for (final moveList in moves.values)
        for (final move in moveList)
          for (final hop in move.hops) hop.abs()
    ];

    // remove dice that aren't usable
    for (final die in _dice.where((d) => d.available)) {
      if (!hops.contains(die.roll)) die.available = false;
    }
  }
}

enum GammonDeltaKind {
  move, // move to empty pip
  hit, // hit a blot
  bar, // been hit
  bearoff, // move off
}

class GammonDelta {
  final GammonDeltaKind kind;
  final int pieceID;
  final int fromPipNo;
  final int toPipNo;
  GammonDelta({@required @required this.kind, this.pieceID, @required this.fromPipNo, @required this.toPipNo});

  @override
  String toString() => '$kind: $pieceID, $fromPipNo=>$toPipNo';

  @override
  bool operator ==(Object o) =>
      (identical(this, o)) ||
      o is GammonDelta && o.kind == kind && o.pieceID == pieceID && o.fromPipNo == fromPipNo && o.toPipNo == toPipNo;

  @override
  int get hashCode => kind.index ^ pieceID ^ fromPipNo.hashCode ^ toPipNo.hashCode;
}

extension GammonMoves on Iterable<GammonMove> {
  List<int> hops({int fromPipNo, int toPipNo}) {
    return firstOrNullWhere((m) => m.fromPipNo == fromPipNo && m.toPipNo == toPipNo)?.hops;
  }

  bool hasHops({int fromPipNo, int toPipNo}) => hops(fromPipNo: fromPipNo, toPipNo: toPipNo) != null;
}

enum Player { one, two }

class GammonMove {
  final int fromPipNo;
  final int toPipNo;
  final hops = <int>[];
  GammonMove({@required this.fromPipNo, @required this.toPipNo, List<int> hops}) {
    assert(this.hops.isEmpty);

    if (hops == null) {
      this.hops.add(toPipNo - fromPipNo);
    } else {
      if (hops.isEmpty) throw Exception('hops must not be empty');
      this.hops.addAll(hops);
    }

    assert(this.hops.all((h) => h.abs() >= 1 && h.abs() <= 6), 'all hops are die rolls');
    assert(this.hops.all((h) => h.sign == this.hops[0].sign), 'all hops must go in the same direction');
    assert(this.hops[0].sign == (toPipNo - fromPipNo).sign, 'movement must be the same direction as hops');
    assert(this.fromPipNo + this.hops.sum() == this.toPipNo, 'hops must total the distance between the two pips');
  }

  Player get player => GammonRules.playerFor(hops[0]);

  @override
  String toString() => 'GammonMove(player: $player, fromPipNo: $fromPipNo, toPipNo: $toPipNo, hops: $hops)';

  @override
  bool operator ==(Object o) =>
      (identical(this, o)) ||
      o is GammonMove && o.fromPipNo == fromPipNo && o.toPipNo == toPipNo && listEquals(o.hops, hops);

  @override
  int get hashCode {
    var hash = fromPipNo.hashCode ^ toPipNo.hashCode;
    for (final hop in hops) hash ^= hop.hashCode;
    return hash;
  }
}

class GammonRules {
  static List<List<int>> initialBoard() => <List<int>>[
        // player1 off, player2 bar
        [], // 0:

        // player1 home board
        [1, 2], // 1: 2x player2
        [], // 2:
        [], // 3:
        [], // 4:
        [], // 5:
        [-15, -14, -13, -12, -11], // 6: 5x player1

        // player1 outer board
        [], // 7:
        [-10, -9, -8], // 8: 3x player1
        [], // 9:
        [], // 10:
        [], // 11:
        [3, 4, 5, 6, 7], // 12: 5x player2

        // player2 outer board
        [-7, -6, -5, -4, -3], // 13: 5x player1
        [], // 14:
        [], // 15:
        [], // 16:
        [8, 9, 10], // 17: 3x player2
        [], // 18:

        // player2 home board
        [11, 12, 13, 14, 15], // 19: 5x player2
        [], // 20:
        [], // 21:
        [], // 22:
        [], // 23:
        [-2, -1], // 24: 2x player1

        // player1 off, player2 bar
        [], // 25:
      ];

  static Player playerFor(int pieceID) => pieceID < 0 ? Player.one : Player.two;
  static int signFor(Player player) => player == Player.one ? -1 : 1;
  static int offPipNoFor(Player player) => player == Player.one ? 0 : 25;
  static int barPipNoFor(Player player) => player == Player.one ? 25 : 0;
  static Player otherPlayer(Player player) => player == Player.one ? Player.two : Player.one;

  static List<List<GammonDelta>> applyMove(List<List<int>> board, GammonMove move) {
    assert(move.hops.length >= 1 && move.hops.length <= 4);
    assert(move.hops.length <= 2 || move.hops.all((h) => h == move.hops[0]),
        'if there are more than two hops, they must be from doubles');

    // track each hop
    final deltas = <List<GammonDelta>>[];
    for (final hop in move.hops) {
      final fromPipNo = deltas.isEmpty ? move.fromPipNo : deltas.last[0].toPipNo;
      final toPipNo = fromPipNo + hop;

      // check each hop
      if (GammonRules.canMove(move.player, fromPipNo, toPipNo, board)) {
        deltas.add([GammonRules.move(board, move.player, fromPipNo, toPipNo)]);
      } else if (GammonRules.canHit(board, move.player, fromPipNo, toPipNo)) {
        deltas.add(GammonRules.hit(board, move.player, fromPipNo, toPipNo));
      } else if (GammonRules.canBearOff(board, move.player, fromPipNo, toPipNo)) {
        deltas.add([GammonRules.bearOff(board, move.player, fromPipNo, toPipNo)]);
      } else {
        // only a legal move if each hop is legal
        deltas.clear();
        break;
      }
    }

    return deltas;
  }

  static void applyDeltasForHop(List<List<int>> board, List<GammonDelta> deltasForHop) {
    if (deltasForHop.isEmpty) return;

    assert(deltasForHop.length == 1 || deltasForHop.length == 2, 'only doing a single hop');
    assert([GammonDeltaKind.bearoff, GammonDeltaKind.hit, GammonDeltaKind.move].contains(deltasForHop[0].kind));
    assert(deltasForHop.length == 1 || deltasForHop[1].pieceID != deltasForHop[0].pieceID);
    assert(deltasForHop.length == 1 || deltasForHop[1].kind == GammonDeltaKind.bar);

    // apply the delta by recreating the move
    final delta = deltasForHop[0];
    final move = GammonMove(fromPipNo: delta.fromPipNo, toPipNo: delta.toPipNo);
    final deltas = applyMove(board, move);

    // check that the deltas we get back match the deltas we were sent
    assert(deltas.length == 1);
    for (var i = 0; i != deltas[0].length; ++i) {
      assert(deltas[0][i] == deltasForHop[i], 'must get back the same delta that was sent in');
    }
  }

  // calculate legal moves for all pips
  static Map<int, List<GammonMove>> getAllLegalMoves(List<List<int>> board, Player player, List<int> rolls) {
    final legalMovesForPips = <int, List<GammonMove>>{};
    for (var pipNo = 0; pipNo != board.length; ++pipNo) {
      final legalMoves = getLegalMoves(board, pipNo, player, rolls).toList();
      assert(legalMoves.length == legalMoves.distinct().length, 'ensure no duplicate moves');
      if (legalMoves.isNotEmpty) legalMovesForPips[pipNo] = legalMoves;
    }

    return legalMovesForPips;
  }

  static List<GammonMove> getLegalMoves(
    List<List<int>> board,
    int fromStartPipNo,
    Player player,
    List<int> rolls,
  ) {
    // are there pieces on this pip?
    final fromPip = board[fromStartPipNo];
    if (fromPip.isEmpty) return [];

    // do the pieces belong to the current player?
    if (!fromPip.any((p) => GammonRules.playerFor(p) == player)) return [];

    // check all components of the _dice for legal moves, taking into account doubles
    // need to uniqify the numbers for trotter
    final stringRolls = [for (var i = 0; i != rolls.length; ++i) '${rolls[i]}${String.fromCharCode(97 + i)}'];

    // use a set to avoid dups generated from doubles
    final legalMoves = <GammonMove>{};

    final comps = Compounds(stringRolls);
    final sign = GammonRules.signFor(player);
    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to be legal
      final hops = [for (final c in comp) int.parse(c.substring(0, 1)) * sign];
      final toEndPipNo = fromStartPipNo + hops.sum();
      final move = GammonMove(fromPipNo: fromStartPipNo, toPipNo: toEndPipNo, hops: hops);
      if (GammonRules.checkLegalMove(board, move).isNotEmpty) {
        final clampedToEndPipNo = toEndPipNo < 0
            ? 0
            : toEndPipNo > 25
                ? 25
                : toEndPipNo;
        legalMoves.add(GammonMove(fromPipNo: move.fromPipNo, toPipNo: clampedToEndPipNo, hops: move.hops));
      }
    }

    return legalMoves.toList();
  }

  static List<List<GammonDelta>> checkLegalMove(List<List<int>> board, GammonMove move) {
    // temp board state while checking each hop of the move
    final tempBoard = List<List<int>>.generate(board.length, (i) => List.from(board[i]));
    return applyMove(tempBoard, move);
  }

  // can the piece can be moved without hitting?
  static bool canMove(Player player, int fromPipNo, int toPipNo, List<List<int>> board) {
    if (fromPipNo < 0 || fromPipNo > 25) return false;
    if (toPipNo < 0 || toPipNo > 25) return false;

    final offPipNo = offPipNoFor(player);
    final barPipNo = barPipNoFor(player);
    if (fromPipNo == offPipNo) return false;
    if (toPipNo == offPipNo) return false;
    if (toPipNo == barPipNo) return false;

    if (!board[fromPipNo].any((p) => playerFor(p) == player)) return false;
    if (board[toPipNo].isEmpty) return true;
    if (playerFor(board[toPipNo][0]) == player) return true;
    return false;
  }

  // move the piece without hitting
  static GammonDelta move(List<List<int>> board, Player player, int fromPipNo, int toPipNo) {
    assert(canMove(player, fromPipNo, toPipNo, board));
    final fromPieces = board[fromPipNo];
    final index = fromPieces.lastIndexWhere((p) => playerFor(p) == player);
    final id = fromPieces.removeAt(index);
    final toPieces = board[toPipNo];
    toPieces.add(id);

    return GammonDelta(kind: GammonDeltaKind.move, pieceID: id, fromPipNo: fromPipNo, toPipNo: toPipNo);
  }

  // can the piece can be hit?
  static bool canHit(List<List<int>> board, Player player, int fromPipNo, int toPipNo) {
    if (fromPipNo < 0 || fromPipNo > 25) return false;
    if (toPipNo < 0 || toPipNo > 25) return false;

    final offPipNo = offPipNoFor(player);
    final barPipNo = barPipNoFor(player);
    if (fromPipNo == offPipNo) return false;
    if (toPipNo == offPipNo) return false;
    if (toPipNo == barPipNo) return false;

    if (!board[fromPipNo].any((p) => playerFor(p) == player)) return false;
    if (board[toPipNo].length != 1) return false;
    if (playerFor(board[toPipNo][0]) != player) return true;
    return false;
  }

  // hit a lone piece
  static List<GammonDelta> hit(List<List<int>> board, Player player, int fromPipNo, int toPipNo) {
    assert(canHit(board, player, fromPipNo, toPipNo));
    final fromPieces = board[fromPipNo];
    final fromIndex = fromPieces.lastIndexWhere((p) => playerFor(p) == player);
    final fromId = fromPieces.removeAt(fromIndex);
    final toPieces = board[toPipNo];
    final toIndex = toPieces.lastIndexWhere((p) => playerFor(p) != player);
    final toId = toPieces.removeAt(toIndex);
    toPieces.add(fromId);
    final barPipNo = barPipNoFor(otherPlayer(player));
    board[barPipNo].add(toId);

    return [
      GammonDelta(kind: GammonDeltaKind.hit, pieceID: fromId, fromPipNo: fromPipNo, toPipNo: toPipNo), // hitter
      GammonDelta(kind: GammonDeltaKind.bar, pieceID: toId, fromPipNo: toPipNo, toPipNo: barPipNo), // hittee
    ];
  }

  static final _playerHomeBoardPipNos = [1.rangeTo(6), 19.rangeTo(24)];
  static final _playerNonHomeBoardPipNos = [7.rangeTo(24), 1.rangeTo(18)];

  // can bear the piece off?
  static bool canBearOff(List<List<int>> board, Player player, int fromPipNo, int toPipNo) {
    if (fromPipNo < 0 || fromPipNo > 25) return false;
    if (toPipNo > 0 && toPipNo < 25) return false;

    // can't move after being born off
    final offPipNo = offPipNoFor(player);
    if (fromPipNo == offPipNo) return false;

    // can't move a piece that isn't there
    if (!board[fromPipNo].any((p) => playerFor(p) == player)) return false;

    // can't bear off if not all of the pieces are in the home board
    final otherPipNos = _playerNonHomeBoardPipNos[player.index];
    for (final pipNo in otherPipNos) if (board[pipNo].any((p) => playerFor(p) == player)) return false;

    // can bear off if moving exactly to the offPipNo
    if (toPipNo == offPipNo) return true;

    // check if it's a forced bear off, i.e. no pieces on pips > fromPipNo
    final greaterHomeBoardPipNos = _playerHomeBoardPipNos[player.index]
        .where((pipNo) => player == Player.one ? pipNo > fromPipNo : pipNo < fromPipNo);
    for (final pipNo in greaterHomeBoardPipNos) if (board[pipNo].any((p) => playerFor(p) == player)) return false;
    return true;
  }

  // bear off the piece
  static GammonDelta bearOff(List<List<int>> board, Player player, int fromPipNo, int toPipNo) {
    assert(canBearOff(board, player, fromPipNo, toPipNo));

    final fromPieces = board[fromPipNo];
    final index = fromPieces.lastIndexWhere((p) => playerFor(p) == player);
    final id = fromPieces.removeAt(index);
    final offPipNo = offPipNoFor(player);
    final offPieces = board[offPipNo];
    offPieces.add(id);

    return GammonDelta(kind: GammonDeltaKind.bearoff, pieceID: id, fromPipNo: fromPipNo, toPipNo: offPipNo);
  }
}
