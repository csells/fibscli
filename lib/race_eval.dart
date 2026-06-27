import 'dart:math';

import 'model.dart';

// Exact race evaluation, ported from the algorithm in race2.c
// (https://bkgm.com/rgb/rgb.cgi?view+787, linked from issue #14).
//
// For a no-contact position the two sides can never hit each other, so the
// outcome is a pure race that can be solved exactly by expectimax: average over
// the 21 distinct dice rolls (doubles weight 1, non-doubles weight 2), choosing
// the checker play that maximises the mover's result, recursing until a side
// has borne everything off. Results are memoised on a piece-id-independent
// signature, which keeps it tractable. Gammons are not modelled (race2.c does
// not either), which is exact for cube/race purposes since gammons are
// impossible once the sides have passed each other.
//
// Cube decisions use the same recursion with cube ownership: a double is worth
// the lesser of the opponent's take and pass equities, and is recommended when
// that exceeds the value of holding the cube.
class RaceEval {
  RaceEval._();

  // Runtime backstop: bail if the memo tables blow past this while solving.
  static const _memoCap = 400000;

  // Upfront size gate: the number of distinct positions a side can reach is at
  // most C(checkers + points - 1, points - 1) (stars and bars). When the
  // product of both sides' counts exceeds this, the exact search would be far
  // too slow, so we skip it WITHOUT enumerating and let the caller fall back to
  // the pip-count heuristic. This keeps the evaluator cheap to *reject* a big
  // race, instead of grinding to _memoCap first.
  static const _solvableStateLimit = 120000;

  /// True when [board] is a pure race small enough for the exact solver to
  /// handle quickly. Cheap (closed form); makes no recursive calls.
  static bool isSolvableRace(List<List<int>> board) =>
      GammonRules.isRace(board) &&
      _estimatedStates(board) <= _solvableStateLimit;

  /// Exact probability that [onRoll] wins the race, or null if the position is
  /// not a pure race or is too large to solve quickly.
  static double? winProbabilityOrNull(
      List<List<int>> board, GammonPlayer onRoll) {
    if (!isSolvableRace(board)) return null;
    try {
      return RaceEval._()._winProb(board, onRoll);
    } on _RaceTooBig {
      return null;
    }
  }

  /// Exact cube action for [onRoll] given the current [cubeOwner] (null =
  /// centered), or null if the position is not a pure race or is too large.
  static CubeAction? cubeActionOrNull(
      List<List<int>> board, GammonPlayer onRoll, GammonPlayer? cubeOwner) {
    if (!isSolvableRace(board)) return null;
    try {
      return RaceEval._()._cubeAction(board, onRoll, cubeOwner);
    } on _RaceTooBig {
      return null;
    }
  }

  // Estimate the combined state-space size: for each player, the number of ways
  // to distribute their on-board checkers over the points from their off pip up
  // to their rearmost checker (stars and bars), capped to keep the math small.
  static int _estimatedStates(List<List<int>> board) {
    var product = 1;
    for (final player in GammonPlayer.values) {
      final offPipNo = GammonRules.offPipNoFor(player);
      var checkers = 0;
      var span = 0;
      for (var pip = 1; pip <= 24; ++pip) {
        final mine = board[pip]
            .where((id) => GammonRules.playerFor(id) == player)
            .length;
        if (mine == 0) continue;
        checkers += mine;
        // distance from this pip back toward the off tray bounds the span
        final depth = (pip - offPipNo).abs();
        if (depth > span) span = depth;
      }
      if (checkers == 0) continue; // all off: a single state
      final points = span < 1 ? 1 : span;
      product *= _choose(checkers + points - 1, points - 1);
      // early out so a huge product can't run away
      if (product > _solvableStateLimit) return product;
    }
    return product;
  }

  // n-choose-k, clamped so a huge value can't overflow before the caller's
  // threshold check (returns just past the limit once it's clearly too big).
  static int _choose(int n, int k) {
    if (k < 0 || k > n) return 0;
    final kk = k > n - k ? n - k : k;
    var result = 1;
    for (var i = 0; i < kk; ++i) {
      result = result * (n - i) ~/ (i + 1);
      if (result > _solvableStateLimit) return _solvableStateLimit + 1;
    }
    return result;
  }

  final _winMemo = <String, double>{};
  final _eqMemo = <String, double>{};

  void _checkCap() {
    if (_winMemo.length + _eqMemo.length > _memoCap) throw _RaceTooBig();
  }

  // --- cubeless win probability ---------------------------------------------

  double _winProb(List<List<int>> board, GammonPlayer toMove) {
    if (_won(board, GammonRules.otherPlayer(toMove))) return 0;

    final key = '${_signature(board)}|${toMove.index}';
    final cached = _winMemo[key];
    if (cached != null) return cached;
    _checkCap();

    var total = 0.0;
    for (var a = 1; a <= 6; ++a) {
      for (var b = a; b <= 6; ++b) {
        final weight = a == b ? 1 : 2;
        var best = 0.0;
        for (final next in _turns(board, toMove, _rollDice(a, b))) {
          final value = _won(next, toMove)
              ? 1.0
              : 1.0 - _winProb(next, GammonRules.otherPlayer(toMove));
          if (value > best) best = value;
        }
        total += weight * best;
      }
    }

    final result = total / 36.0;
    _winMemo[key] = result;
    return result;
  }

  // --- cubeful equity (per unit of the current cube) ------------------------

  // owner: 0 == centered, 1 == toMove owns, 2 == opponent owns.
  double _unitEquity(List<List<int>> board, GammonPlayer toMove, int owner) {
    final hold = _unitRoll(board, toMove, owner);
    if (owner == 2) return hold; // opponent owns the cube; toMove can't double

    const passValue = 1.0; // opponent drops: toMove wins the current stake
    final takeValue = 2.0 * _unitEquity(board, toMove, 2); // doubled, opp owns
    final doubled = min(passValue, takeValue);
    return max(hold, doubled);
  }

  double _unitRoll(List<List<int>> board, GammonPlayer toMove, int owner) {
    if (_won(board, GammonRules.otherPlayer(toMove))) return -1;

    final key = 'R|${_signature(board)}|${toMove.index}|$owner';
    final cached = _eqMemo[key];
    if (cached != null) return cached;
    _checkCap();

    var total = 0.0;
    for (var a = 1; a <= 6; ++a) {
      for (var b = a; b <= 6; ++b) {
        final weight = a == b ? 1 : 2;
        var best = double.negativeInfinity;
        for (final next in _turns(board, toMove, _rollDice(a, b))) {
          final value = _won(next, toMove)
              ? 1.0
              : -_unitEquity(
                  next, GammonRules.otherPlayer(toMove), _flip(owner));
          if (value > best) best = value;
        }
        total += weight * best;
      }
    }

    final result = total / 36.0;
    _eqMemo[key] = result;
    return result;
  }

  CubeAction _cubeAction(
      List<List<int>> board, GammonPlayer toMove, GammonPlayer? cubeOwner) {
    final owner = cubeOwner == null ? 0 : (cubeOwner == toMove ? 1 : 2);
    if (owner == 2) return CubeAction.noDouble; // can't double; opponent owns

    final hold = _unitRoll(board, toMove, owner);
    const passValue = 1.0;
    final takeValue = 2.0 * _unitEquity(board, toMove, 2);
    final doubled = min(passValue, takeValue);

    const epsilon = 1e-9;
    if (doubled > hold + epsilon) {
      return takeValue <= passValue + epsilon
          ? CubeAction.doubleTake
          : CubeAction.doublePass;
    }
    return CubeAction.noDouble;
  }

  static int _flip(int owner) => owner == 0 ? 0 : (owner == 1 ? 2 : 1);

  // --- move enumeration -----------------------------------------------------

  static List<int> _rollDice(int a, int b) =>
      a == b ? [a, a, a, a] : [a, b];

  // Every distinct board reachable by playing a full turn with [rolls], using
  // the maximum number of dice the rules require.
  static List<List<List<int>>> _turns(
      List<List<int>> board, GammonPlayer player, List<int> rolls) {
    final byDepth = <int, List<List<List<int>>>>{};

    void search(List<List<int>> current, List<int> remaining, int depth) {
      var moved = false;
      final tried = <int>{};
      for (final die in remaining) {
        if (!tried.add(die)) continue;
        final movesByPip = GammonRules.getAllLegalMoves(current, player, [die]);
        for (final moves in movesByPip.values) {
          for (final move in moves) {
            final next = _copy(current);
            if (GammonRules.applyMove(next, move).isEmpty) continue;
            moved = true;
            search(next, List<int>.of(remaining)..remove(die), depth + 1);
          }
        }
      }
      if (!moved) (byDepth[depth] ??= []).add(current);
    }

    search(board, rolls, 0);
    if (byDepth.isEmpty) return [board];

    final maxDepth = byDepth.keys.reduce(max);
    final seen = <String>{};
    final result = <List<List<int>>>[];
    for (final candidate in byDepth[maxDepth]!) {
      if (seen.add(_signature(candidate))) result.add(candidate);
    }
    return result;
  }

  // --- board helpers --------------------------------------------------------

  static List<List<int>> _copy(List<List<int>> board) =>
      List<List<int>>.generate(board.length, (i) => List<int>.from(board[i]));

  // Piece ids don't affect the race outcome, so the memo key is just the net
  // checker count per pip (negative = player1, positive = player2).
  static String _signature(List<List<int>> board) {
    final sb = StringBuffer();
    for (final pip in board) {
      var count = 0;
      for (final id in pip) {
        count += GammonRules.playerFor(id) == GammonPlayer.one ? -1 : 1;
      }
      sb
        ..write(count)
        ..write(',');
    }
    return sb.toString();
  }

  static bool _won(List<List<int>> board, GammonPlayer player) {
    final offPipNo = GammonRules.offPipNoFor(player);
    for (var pip = 0; pip != board.length; ++pip) {
      if (pip == offPipNo) continue;
      if (board[pip].any((id) => GammonRules.playerFor(id) == player)) {
        return false;
      }
    }
    return true;
  }
}

class _RaceTooBig implements Exception {}
