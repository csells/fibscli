import 'dart:math';

import 'package:collection/collection.dart' show ListEquality;
import 'package:dartx/dartx.dart';
import 'package:meta/meta.dart';
import 'package:trotter/trotter.dart';

/// The doubling cube (issue #12). Starts centered (owned by neither) at 1.
/// Taking a double doubles the stake and transfers ownership to the taker, who
/// alone may then redouble. The value tops out at 64.
class DoublingCube {
  /// The cube can never be doubled past this value.
  static const maxValue = 64;

  /// The current cube value (a power of two, 1..64).
  int value = 1;

  /// The player who currently owns (may turn) the cube; null == centered.
  GammonPlayer? owner; // null == centered, either player may double

  /// Whether [player] is allowed to offer a double now (owns or centered, and
  /// not already at [maxValue]).
  bool canDoubleBy(GammonPlayer player) =>
      value < maxValue && (owner == null || owner == player);

  /// Apply an accepted double offered by [offeredBy]: the taker (the other
  /// player) becomes the new owner and the value doubles.
  void applyTake(GammonPlayer offeredBy) {
    assert(canDoubleBy(offeredBy));
    value *= 2;
    owner = GammonRules.otherPlayer(offeredBy);
  }
}

/// The atomic effect a single hop of a move has on the board.
enum GammonDeltaKind {
  /// Move a checker to an empty (or own) pip.
  move,

  /// Hit an opponent blot on the destination pip.
  hit,

  /// A checker that was hit goes to the bar.
  bar,

  /// Bear a checker off the board.
  bearoff,
}

/// One atomic board change produced by applying a move: a single checker
/// (identified by [pieceID]) moving from [fromPipNo] to [toPipNo] with [kind].
@immutable
class GammonDelta {
  /// Creates a delta describing one atomic board change.
  const GammonDelta({
    required this.kind,
    required this.fromPipNo,
    required this.toPipNo,
    this.pieceID,
  });

  /// What kind of change this is (move/hit/bar/bearoff).
  final GammonDeltaKind kind;

  /// The signed id of the checker affected (null when not applicable).
  final int? pieceID;

  /// The pip the checker moved from.
  final int fromPipNo;

  /// The pip the checker moved to.
  final int toPipNo;

  @override
  String toString() => '$kind: $pieceID, $fromPipNo=>$toPipNo';

  @override
  bool operator ==(Object other) =>
      (identical(this, other)) ||
      other is GammonDelta &&
          other.kind == kind &&
          other.pieceID == pieceID &&
          other.fromPipNo == fromPipNo &&
          other.toPipNo == toPipNo;

  @override
  int get hashCode =>
      kind.index ^ pieceID! ^ fromPipNo.hashCode ^ toPipNo.hashCode;
}

/// Lookups over a collection of candidate [GammonMove]s by endpoint pips.
extension GammonMoves on Iterable<GammonMove>? {
  /// The hop list of the move from [fromPipNo] to [toPipNo], or null if none.
  List<int>? hops({int? fromPipNo, int? toPipNo}) => this!
      .firstOrNullWhere((m) => m.fromPipNo == fromPipNo && m.toPipNo == toPipNo)
      ?.hops;

  /// Whether a move from [fromPipNo] to [toPipNo] exists in the collection.
  bool hasHops({int? fromPipNo, int? toPipNo}) =>
      hops(fromPipNo: fromPipNo, toPipNo: toPipNo) != null;
}

/// The two players. Sign encodes ownership on the board: player [one] checkers
/// are negative ids, player [two] checkers are positive.
enum GammonPlayer {
  /// Player 1 (negative piece ids; bears off toward pip 0).
  one,

  /// Player 2 (positive piece ids; bears off toward pip 25).
  two,
}

/// Recommended doubling-cube action for the player on roll (issue #14).
enum CubeAction {
  /// Too early to double; just roll.
  noDouble,

  /// Offer a double; the opponent should take.
  doubleTake,

  /// Offer a double; the opponent should pass (drop).
  doublePass,
}

/// A single checker's full move for a turn: from [fromPipNo] to [toPipNo] via
/// one or more [hops] (each hop is a die roll; doubles can chain up to four).
@immutable
class GammonMove {
  /// Creates a move from [fromPipNo] to [toPipNo]. If [hops] is omitted the
  /// move is a single hop of `toPipNo - fromPipNo`; otherwise [hops] are the
  /// per-die deltas, validated to be legal die rolls in one direction.
  GammonMove({
    required this.fromPipNo,
    required this.toPipNo,
    List<int>? hops,
  }) {
    assert(this.hops.isEmpty);

    if (hops == null) {
      this.hops.add(toPipNo - fromPipNo);
    } else {
      if (hops.isEmpty) throw Exception('hops must not be empty');
      this.hops.addAll(hops);
    }

    assert(
      this.hops.all((h) => h.abs() >= 1 && h.abs() <= 6),
      'all hops are die rolls',
    );
    assert(
      this.hops.all((h) => h.sign == this.hops[0].sign),
      'all hops must go in the same direction',
    );
    assert(
      this.hops[0].sign == (toPipNo - fromPipNo).sign,
      'movement must be the same direction as hops',
    );
    assert(
      this.hops.sum().abs() >= (toPipNo - fromPipNo).abs(),
      'hops must total the distance between the two pips '
      '(or greater, if bearing off)',
    );
  }

  /// The pip the checker starts on.
  final int fromPipNo;

  /// The pip the checker ends on.
  final int toPipNo;

  /// The per-die hop deltas that make up this move (signed by direction).
  final hops = <int>[];

  /// The player making the move (derived from the hop direction).
  GammonPlayer get player => GammonRules.playerFor(hops[0]);

  @override
  String toString() =>
      'GammonMove(player: $player, fromPipNo: $fromPipNo, '
      'toPipNo: $toPipNo, hops: $hops)';

  @override
  bool operator ==(Object other) =>
      (identical(this, other)) ||
      other is GammonMove &&
          other.fromPipNo == fromPipNo &&
          other.toPipNo == toPipNo &&
          const ListEquality<int>().equals(other.hops, hops);

  @override
  int get hashCode {
    var hash = fromPipNo.hashCode ^ toPipNo.hashCode;
    for (final hop in hops) {
      hash ^= hop.hashCode;
    }
    return hash;
  }
}

/// The stateless backgammon rule set: legal-move generation, move application,
/// and bear-off/bar/hit logic. All methods are static (no instances) and
/// operate on the canonical board — a length-26 `List<List<int>>` whose inner
/// lists hold signed piece ids (negative = player1, positive = player2).
class GammonRules {
  /// A fresh board in the standard opening position.
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

  /// The player that owns a checker, from the sign of its [pieceID].
  static GammonPlayer playerFor(int pieceID) =>
      pieceID < 0 ? GammonPlayer.one : GammonPlayer.two;

  /// The number of [player]'s checkers on [board] at [pip]. The one place the
  /// "count a player's checkers on a point" idiom lives (callers used to
  /// re-derive it via `.where(playerFor == player).length` all over).
  static int countAt(List<List<int>> board, int pip, GammonPlayer player) {
    var n = 0;
    for (final id in board[pip]) {
      if (playerFor(id) == player) n++;
    }
    return n;
  }

  /// The ownership sign for [player] (player1 = -1, player2 = +1).
  static int signFor(GammonPlayer? player) =>
      player == GammonPlayer.one ? -1 : 1;

  /// The board index where [player] bears checkers off (player1 = 0,
  /// player2 = 25).
  static int offPipNoFor(GammonPlayer? player) =>
      player == GammonPlayer.one ? 0 : 25;

  /// The board index of [player]'s bar (player1 = 25, player2 = 0).
  static int barPipNoFor(GammonPlayer player) =>
      player == GammonPlayer.one ? 25 : 0;

  /// The opponent of [player].
  static GammonPlayer otherPlayer(GammonPlayer? player) =>
      player == GammonPlayer.one ? GammonPlayer.two : GammonPlayer.one;

  /// Compute the per-hop deltas for applying [move] to [board], or an empty
  /// list if any hop is illegal. Does not mutate [board].
  static List<List<GammonDelta>> applyMove(
    List<List<int>> board,
    GammonMove move,
  ) {
    assert(move.hops.isNotEmpty && move.hops.length <= 4);
    assert(
      move.hops.length <= 2 || move.hops.all((h) => h == move.hops[0]),
      'if there are more than two hops, they must be from doubles',
    );

    // track each hop
    final deltas = <List<GammonDelta>>[];
    for (final hop in move.hops) {
      final fromPipNo = deltas.isEmpty
          ? move.fromPipNo
          : deltas.last[0].toPipNo;
      final toPipNo = fromPipNo + hop;

      // check each hop
      if (GammonRules.canMove(move.player, fromPipNo, toPipNo, board)) {
        deltas.add([GammonRules.move(board, move.player, fromPipNo, toPipNo)]);
      } else if (GammonRules.canHit(board, move.player, fromPipNo, toPipNo)) {
        deltas.add(GammonRules.hit(board, move.player, fromPipNo, toPipNo));
      } else if (GammonRules.canBearOff(
        board,
        move.player,
        fromPipNo,
        toPipNo,
      )) {
        deltas.add([
          GammonRules.bearOff(board, move.player, fromPipNo, toPipNo),
        ]);
      } else {
        // only a legal move if each hop is legal
        deltas.clear();
        break;
      }
    }

    return deltas;
  }

  /// Apply the deltas for a single hop to [board], mutating it in place
  /// (re-deriving the move from the deltas and asserting they round-trip).
  static void applyDeltasForHop(
    List<List<int>> board,
    List<GammonDelta> deltasForHop,
  ) {
    if (deltasForHop.isEmpty) return;

    assert(
      deltasForHop.length == 1 || deltasForHop.length == 2,
      'only doing a single hop',
    );
    assert(
      [
        GammonDeltaKind.bearoff,
        GammonDeltaKind.hit,
        GammonDeltaKind.move,
      ].contains(deltasForHop[0].kind),
    );
    assert(
      deltasForHop.length == 1 ||
          deltasForHop[1].pieceID != deltasForHop[0].pieceID,
    );
    assert(
      deltasForHop.length == 1 || deltasForHop[1].kind == GammonDeltaKind.bar,
    );

    // apply the delta by recreating the move
    final delta = deltasForHop[0];
    final move = GammonMove(fromPipNo: delta.fromPipNo, toPipNo: delta.toPipNo);
    final deltas = applyMove(board, move);

    // check that the deltas we get back match the deltas we were sent
    assert(deltas.length == 1);
    for (var i = 0; i != deltas[0].length; ++i) {
      assert(
        deltas[0][i] == deltasForHop[i],
        'must get back the same delta that was sent in',
      );
    }
  }

  /// True when the two players' checkers have passed each other so no further
  /// hits are possible: a pure race. Used to offer auto bear-off (issue #11).
  static bool isRace(List<List<int>> board) {
    // any checker on the bar means contact is still possible
    if (board[0].any((p) => playerFor(p) == GammonPlayer.two)) return false;
    if (board[25].any((p) => playerFor(p) == GammonPlayer.one)) return false;

    int? p1Max; // highest point player1 occupies (player1's rearmost)
    int? p2Min; // lowest point player2 occupies (player2's rearmost)
    for (var pip = 1; pip <= 24; ++pip) {
      for (final id in board[pip]) {
        if (playerFor(id) == GammonPlayer.one) {
          p1Max = p1Max == null ? pip : max(p1Max, pip);
        } else {
          p2Min = p2Min == null ? pip : min(p2Min, pip);
        }
      }
    }

    // if either side is entirely off the board, it's trivially a race
    if (p1Max == null || p2Min == null) return true;
    return p1Max < p2Min;
  }

  /// Greedy bear-off choice for a single die (issue #11): bear a checker off if
  /// possible, clearing the highest such point; otherwise advance the rearmost
  /// checker. Returns null when the die has no legal play.
  static GammonMove? greedyMoveForDie(
    List<List<int>> board,
    GammonPlayer? player,
    int die,
  ) {
    final movesByPip = getAllLegalMoves(board, player, [die]);
    final candidates = <GammonMove>[
      for (final moves in movesByPip.values) ...moves,
    ];
    if (candidates.isEmpty) return null;

    // "rearness": how far from home a point is for this player (higher == more
    // checker work remaining), so the rearmost checker has the largest value.
    int rearness(int pipNo) => player == GammonPlayer.one ? pipNo : -pipNo;

    final offPipNo = offPipNoFor(player);
    final bearoffs = candidates.where((m) => m.toPipNo == offPipNo).toList();
    final pool = bearoffs.isNotEmpty ? bearoffs : candidates;
    pool.sort((a, b) => rearness(b.fromPipNo).compareTo(rearness(a.fromPipNo)));
    return pool.first;
  }

  /// A greedy full turn for [player] with [dice] from [board] (issue #11):
  /// repeatedly play a move that bears a checker off if one exists, else
  /// advance the rear-most checker, until the dice are spent. Returns the moves
  /// (to apply/submit); [board] is not mutated. Only sensible in a pure race
  /// (no decision affects the outcome) -- callers gate on [isRace].
  static List<GammonMove> autoBearOffTurn(
    List<List<int>> board,
    GammonPlayer? player,
    List<int> dice,
  ) {
    final work = copyBoard(board);
    final remaining = List<int>.of(dice);
    final chosen = <GammonMove>[];
    int rearness(int pipNo) => player == GammonPlayer.one ? pipNo : -pipNo;
    final offPipNo = offPipNoFor(player);

    while (remaining.isNotEmpty) {
      final legal = getForcedLegalMoves(work, player, remaining);
      if (legal.isEmpty) break;

      // prefer a move that bears a checker off; else advance the rear-most
      GammonMove? move;
      for (final moves in legal.values) {
        for (final m in moves) {
          if (m.toPipNo == offPipNo) {
            move = m;
            break;
          }
        }
        if (move != null) break;
      }
      if (move == null) {
        final fromPips = legal.keys.toList()
          ..sort((a, b) => rearness(b).compareTo(rearness(a)));
        move = legal[fromPips.first]!.first;
      }

      chosen.add(move);
      applyMove(work, move);
      for (final hop in move.hops) {
        remaining.remove(hop.abs());
      }
    }
    return chosen;
  }

  /// A deep copy of the engine board (each point list is copied), so callers
  /// can try a move without mutating the original. The one canonical board copy
  /// in the engine -- `turn_search`/`RaceEval` delegate here.
  static List<List<int>> copyBoard(List<List<int>> board) =>
      List<List<int>>.generate(board.length, (i) => List<int>.of(board[i]));

  /// The maximum number of dice (single hops) that can be legally played this
  /// turn, considering every move ordering. For non-doubles this is 0, 1, or 2;
  /// for doubles up to 4. Used to enforce the rule that a player must play as
  /// many dice as possible (issue #4).
  static int maxPlayableDice(
    List<List<int>> board,
    GammonPlayer? player,
    List<int> rolls,
  ) {
    if (rolls.isEmpty) return 0;

    var best = 0;
    final tried = <int>{};
    for (final roll in rolls) {
      if (!tried.add(roll)) continue; // doubles: same value, same result
      final remaining = List<int>.of(rolls)..remove(roll);

      // every legal single-die play for this roll, from any pip
      final movesByPip = getAllLegalMoves(board, player, [roll]);
      for (final moves in movesByPip.values) {
        for (final move in moves) {
          final tempBoard = copyBoard(board);
          final deltas = applyMove(tempBoard, move);
          if (deltas.isEmpty) continue;
          final depth = 1 + maxPlayableDice(tempBoard, player, remaining);
          if (depth > best) best = depth;
          if (best == rolls.length) return best; // can't do better
        }
      }
    }
    return best;
  }

  static List<int> _rollsAfter(List<int> rolls, Iterable<int> hops) {
    final remaining = List<int>.of(rolls);
    for (final hop in hops) {
      remaining.remove(hop.abs());
    }
    return remaining;
  }

  /// Like [getAllLegalMoves], but restricted to the moves a player is actually
  /// allowed to make under the forced-move rules: a player must use as many
  /// dice as possible, and when only one of two different dice can be played,
  /// must play the larger one (issue #4).
  static Map<int, List<GammonMove>> getForcedLegalMoves(
    List<List<int>> board,
    GammonPlayer? player,
    List<int> rolls,
  ) {
    final maxDice = maxPlayableDice(board, player, rolls);
    if (maxDice == 0) return {};

    final all = getAllLegalMoves(board, player, rolls);
    final result = <int, List<GammonMove>>{};
    for (final entry in all.entries) {
      final kept = <GammonMove>[];
      for (final move in entry.value) {
        final tempBoard = copyBoard(board);
        final deltas = applyMove(tempBoard, move);
        if (deltas.isEmpty) continue;
        final remaining = _rollsAfter(rolls, move.hops);
        final reachable =
            move.hops.length + maxPlayableDice(tempBoard, player, remaining);
        if (reachable == maxDice) kept.add(move);
      }
      if (kept.isNotEmpty) result[entry.key] = kept;
    }

    // larger-die rule: when only a single die can be played and the two dice
    // differ, the player must play the larger one.
    if (maxDice == 1) {
      final dieValues = {
        for (final moves in result.values)
          for (final move in moves) move.hops.first.abs(),
      };
      if (dieValues.length > 1) {
        final largest = dieValues.reduce(max);
        for (final pipNo in result.keys.toList()) {
          final kept = result[pipNo]!
              .where((m) => m.hops.first.abs() == largest)
              .toList();
          if (kept.isEmpty) {
            result.remove(pipNo);
          } else {
            result[pipNo] = kept;
          }
        }
      }
    }

    return result;
  }

  /// Every legal move this turn, keyed by the from-pip (issue #4 unconstrained:
  /// see [getForcedLegalMoves] for the must-use-most-dice variant).
  static Map<int, List<GammonMove>> getAllLegalMoves(
    List<List<int>> board,
    GammonPlayer? player,
    List<int> rolls,
  ) {
    final legalMovesForPips = <int, List<GammonMove>>{};
    for (var pipNo = 0; pipNo != board.length; ++pipNo) {
      final legalMoves = getLegalMoves(board, pipNo, player, rolls).toList();
      assert(
        legalMoves.length == legalMoves.distinct().length,
        'ensure no duplicate moves',
      );
      if (legalMoves.isNotEmpty) legalMovesForPips[pipNo] = legalMoves;
    }

    return legalMovesForPips;
  }

  /// Every legal move starting from [fromStartPipNo] for [player] with [rolls]
  /// (including multi-hop combinations of the dice).
  static List<GammonMove> getLegalMoves(
    List<List<int>> board,
    int fromStartPipNo,
    GammonPlayer? player,
    List<int> rolls,
  ) {
    // are there pieces on this pip?
    final fromPip = board[fromStartPipNo];
    if (fromPip.isEmpty) return [];

    // do the pieces belong to the current player?
    if (!fromPip.any((p) => GammonRules.playerFor(p) == player)) return [];

    // check all components of the _dice for legal moves, taking into account
    // doubles. need to uniqify the numbers for trotter
    final stringRolls = <String>[
      for (var i = 0; i != rolls.length; ++i)
        '${rolls[i]}${String.fromCharCode(97 + i)}',
    ];

    // use a set to avoid dups generated from doubles
    final legalMoves = <GammonMove>{};

    final comps = Compounds<String>(stringRolls);
    final sign = GammonRules.signFor(player);
    for (final comp in comps().where((comp) => comp.isNotEmpty)) {
      // check if all of the moves along the way are legal for this compound to
      // be legal
      final hops = <int>[
        for (final c in comp) int.parse(c.substring(0, 1)) * sign,
      ];
      final toEndPipNo = fromStartPipNo + hops.sum();
      final move = GammonMove(
        fromPipNo: fromStartPipNo,
        toPipNo: toEndPipNo,
        hops: hops,
      );
      if (GammonRules.checkLegalMove(board, move).isNotEmpty) {
        final clampedToEndPipNo = toEndPipNo < 0
            ? 0
            : toEndPipNo > 25
            ? 25
            : toEndPipNo;
        legalMoves.add(
          GammonMove(
            fromPipNo: move.fromPipNo,
            toPipNo: clampedToEndPipNo,
            hops: move.hops,
          ),
        );
      }
    }

    return legalMoves.toList();
  }

  /// Count how many opponent blots [move] hits along the way.
  static int hitCountForMove(List<List<int>> board, GammonMove move) {
    final deltas = checkLegalMove(board, move);
    return deltas
        .expand((deltasForHop) => deltasForHop)
        .where((delta) => delta.kind == GammonDeltaKind.hit)
        .length;
  }

  /// Among [moves] that go from [fromPipNo] to [toPipNo], return the hops of
  /// the one that hits the most opponent blots along the way. When the
  /// destination can be reached via several hop orderings (e.g. 8->5->4 vs
  /// 8->7->4), this prefers an ordering that hits rather than an arbitrary one.
  /// Returns null if no matching move exists (issue #9).
  static List<int>? preferredHops(
    List<List<int>> board,
    Iterable<GammonMove> moves, {
    required int fromPipNo,
    required int toPipNo,
  }) {
    final matching = moves
        .where((m) => m.fromPipNo == fromPipNo && m.toPipNo == toPipNo)
        .toList();
    if (matching.isEmpty) return null;

    matching.sort(
      (a, b) => hitCountForMove(board, b).compareTo(hitCountForMove(board, a)),
    );
    return matching.first.hops;
  }

  /// Whether [move] is legal, returned as its per-hop deltas (empty if not).
  /// Checks against a copy, so [board] is not mutated.
  static List<List<GammonDelta>> checkLegalMove(
    List<List<int>> board,
    GammonMove move,
  ) => applyMove(copyBoard(board), move);

  // Shared reachability guard for canMove/canHit: on-board coordinates, not
  // from/to the off tray or into our own bar, bar checkers must enter first,
  // and we actually own a checker on [fromPipNo]. Only the DESTINATION test
  // (empty/own vs. lone opponent) differs between the two, so that stays in the
  // callers.
  static bool _canReach(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    if (fromPipNo < 0 || fromPipNo > 25) return false;
    if (toPipNo < 0 || toPipNo > 25) return false;

    final offPipNo = offPipNoFor(player);
    final barPipNo = barPipNoFor(player);
    if (fromPipNo == offPipNo) return false;
    if (toPipNo == offPipNo) return false;
    if (toPipNo == barPipNo) return false;

    final hasBarPieces = board[barPipNo].any((pid) => playerFor(pid) == player);
    if (hasBarPieces && fromPipNo != barPipNo) return false;

    return board[fromPipNo].any((p) => playerFor(p) == player);
  }

  // Remove and return the id of [player]'s top checker on [fromPipNo]. Shared
  // by move/hit/bearOff, which all pick up the mover the same way.
  static int _pickUp(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
  ) {
    final pieces = board[fromPipNo];
    final index = pieces.lastIndexWhere((p) => playerFor(p) == player);
    return pieces.removeAt(index);
  }

  /// Whether [player] can move a checker from [fromPipNo] to [toPipNo] without
  /// hitting (destination empty or own; bar checkers must come in first).
  static bool canMove(
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
    List<List<int>> board,
  ) {
    if (!_canReach(board, player, fromPipNo, toPipNo)) return false;
    if (board[toPipNo].isEmpty) return true;
    return playerFor(board[toPipNo][0]) == player;
  }

  /// Move a checker from [fromPipNo] to [toPipNo] (no hit), mutating [board]
  /// and returning the resulting delta. Asserts the move is legal.
  static GammonDelta move(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    assert(canMove(player, fromPipNo, toPipNo, board));
    final id = _pickUp(board, player, fromPipNo);
    board[toPipNo].add(id);

    return GammonDelta(
      kind: GammonDeltaKind.move,
      pieceID: id,
      fromPipNo: fromPipNo,
      toPipNo: toPipNo,
    );
  }

  /// Whether moving from [fromPipNo] to [toPipNo] would hit an opponent blot
  /// (a single opposing checker) on the destination pip.
  static bool canHit(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    if (!_canReach(board, player, fromPipNo, toPipNo)) return false;
    if (board[toPipNo].length != 1) return false;
    return playerFor(board[toPipNo][0]) != player;
  }

  /// Hit the opponent blot on [toPipNo]: move our checker there and send the
  /// hit checker to the bar, mutating [board]. Returns the move + bar deltas.
  static List<GammonDelta> hit(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    assert(canHit(board, player, fromPipNo, toPipNo));
    final fromId = _pickUp(board, player, fromPipNo);
    final toPieces = board[toPipNo];
    final toIndex = toPieces.lastIndexWhere((p) => playerFor(p) != player);
    final toId = toPieces.removeAt(toIndex);
    toPieces.add(fromId);
    final barPipNo = barPipNoFor(otherPlayer(player));
    board[barPipNo].add(toId);

    return [
      GammonDelta(
        kind: GammonDeltaKind.hit,
        pieceID: fromId,
        fromPipNo: fromPipNo,
        toPipNo: toPipNo,
      ), // hitter
      GammonDelta(
        kind: GammonDeltaKind.bar,
        pieceID: toId,
        fromPipNo: toPipNo,
        toPipNo: barPipNo,
      ), // hittee
    ];
  }

  static final _playerHomeBoardPipNos = [1.rangeTo(6), 19.rangeTo(24)];
  // Everything that is NOT the player's home board AND not their off tray --
  // crucially this includes the player's BAR (pip 25 for player one, pip 0 for
  // player two), so a checker on the bar correctly blocks bearing off.
  static final _playerNonHomeBoardPipNos = [7.rangeTo(25), 0.rangeTo(18)];

  /// Whether [player] may bear a checker off from [fromPipNo] to [toPipNo]
  /// (all checkers home, and either an exact roll or no checker further back).
  static bool canBearOff(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    if (fromPipNo < 0 || fromPipNo > 25) return false;
    if (toPipNo > 0 && toPipNo < 25) return false;

    // can't move after being born off
    final offPipNo = offPipNoFor(player);
    if (fromPipNo == offPipNo) return false;

    // can't move a piece that isn't there
    if (!board[fromPipNo].any((p) => playerFor(p) == player)) return false;

    // can't bear off if not all of the pieces are in the home board
    final otherPipNos = _playerNonHomeBoardPipNos[player.index];
    for (final pipNo in otherPipNos) {
      if (board[pipNo].any((p) => playerFor(p) == player)) return false;
    }

    // can bear off if moving exactly to the offPipNo
    if (toPipNo == offPipNo) return true;

    // check if it's a forced bear off, i.e. no pieces on pips > fromPipNo
    final greaterHomeBoardPipNos = _playerHomeBoardPipNos[player.index].where(
      (pipNo) =>
          player == GammonPlayer.one ? pipNo > fromPipNo : pipNo < fromPipNo,
    );
    for (final pipNo in greaterHomeBoardPipNos) {
      if (board[pipNo].any((p) => playerFor(p) == player)) return false;
    }
    return true;
  }

  /// Bear a checker off from [fromPipNo], mutating [board] and returning the
  /// bearoff delta. Asserts the bear-off is legal.
  static GammonDelta bearOff(
    List<List<int>> board,
    GammonPlayer player,
    int fromPipNo,
    int toPipNo,
  ) {
    assert(canBearOff(board, player, fromPipNo, toPipNo));

    final id = _pickUp(board, player, fromPipNo);
    final offPipNo = offPipNoFor(player);
    board[offPipNo].add(id);

    return GammonDelta(
      kind: GammonDeltaKind.bearoff,
      pieceID: id,
      fromPipNo: fromPipNo,
      toPipNo: offPipNo,
    );
  }
}
