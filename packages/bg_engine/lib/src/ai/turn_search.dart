import '../board_signature.dart';
import '../rules.dart';

/// One complete legal turn: the ordered [moves] and the [board] that results
/// from applying them. An empty [moves] list is a dance.
class LegalTurn {
  /// Creates a legal turn from its [moves] and resulting [board].
  const LegalTurn(this.moves, this.board);

  /// The ordered moves making up the turn.
  final List<GammonMove> moves;

  /// The board after the turn has been applied (signed piece ids).
  final List<List<int>> board;
}

/// Enumerate every legal full turn for [player] with [dice] from [board],
/// respecting the forced-move rules (a player must play as many dice as
/// possible). Each result carries the move sequence and the resulting board.
/// A dance yields a single turn with no moves.
List<LegalTurn> enumerateLegalTurns(
  List<List<int>> board,
  GammonPlayer player,
  List<int> dice,
) {
  final results = <LegalTurn>[];
  // Prune transpositions: different move orders that reach the same position
  // with the same dice left are explored once (so doubles can't blow up).
  final seen = <String>{};

  void expand(
    List<List<int>> curBoard,
    List<int> curDice,
    List<GammonMove> moves,
  ) {
    final forced = GammonRules.getForcedLegalMoves(curBoard, player, curDice);
    if (forced.isEmpty) {
      results.add(LegalTurn(List<GammonMove>.unmodifiable(moves), curBoard));
      return;
    }
    for (final moveList in forced.values) {
      for (final move in moveList) {
        final next = GammonRules.copyBoard(curBoard);
        final deltas = GammonRules.applyMove(next, move); // mutates next
        if (deltas.isEmpty) continue;
        final rest = _removeHops(curDice, move.hops);
        final key = '${netSignature(next)}|${rest.toList()..sort()}';
        if (!seen.add(key)) continue;
        expand(next, rest, [...moves, move]);
      }
    }
  }

  expand(board, dice, const []);
  return results;
}

/// A position fingerprint independent of piece ids: per pip, the (player1,
/// player2) checker counts, as a flat list `[p1@0, p2@0, p1@1, p2@1, …]`. Two
/// positions are equal iff their signatures are. Used by the gnubg and
/// backgammon_ai adapters to match an external engine's chosen position back to
/// a locally-enumerated legal turn.
List<int> positionSignature(List<List<int>> board) {
  final sig = List<int>.filled(board.length * 2, 0);
  for (var i = 0; i < board.length; i++) {
    for (final id in board[i]) {
      if (id < 0) {
        sig[i * 2]++;
      } else {
        sig[i * 2 + 1]++;
      }
    }
  }
  return sig;
}

/// The first turn in [turns] whose resulting board matches [targetSignature]
/// (a [positionSignature]), or null if none. Lets an external-engine adapter
/// map the position that engine chose back to a concrete legal move sequence.
/// Returns [LegalTurn] (not `BgTurn`) to stay independent of the AI-player API.
LegalTurn? matchTurnBySignature(
  List<LegalTurn> turns,
  List<int> targetSignature,
) {
  for (final turn in turns) {
    if (_sigEquals(positionSignature(turn.board), targetSignature)) return turn;
  }
  return null;
}

bool _sigEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<int> _removeHops(List<int> dice, List<int> hops) {
  final remaining = List<int>.of(dice);
  for (final hop in hops) {
    remaining.remove(hop.abs());
  }
  return remaining;
}
