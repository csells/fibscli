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
        final next = copyBoard(curBoard);
        final deltas = GammonRules.applyMove(next, move); // mutates next
        if (deltas.isEmpty) continue;
        expand(next, _removeHops(curDice, move.hops), [...moves, move]);
      }
    }
  }

  expand(board, dice, const []);
  return results;
}

/// A deep copy of a 26-cell engine board.
List<List<int>> copyBoard(List<List<int>> board) =>
    List<List<int>>.generate(board.length, (i) => List<int>.of(board[i]));

List<int> _removeHops(List<int> dice, List<int> hops) {
  final remaining = List<int>.of(dice);
  for (final hop in hops) {
    remaining.remove(hop.abs());
  }
  return remaining;
}
