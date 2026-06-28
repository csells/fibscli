import '../pubeval.dart';
import '../rules.dart';
import 'bg_ai_player.dart';

/// The out-of-the-box heuristic AI: enumerates every legal full turn from the
/// position and plays the one whose resulting board the [PubEval] evaluator
/// scores highest from the mover's perspective (~1650 FIBS strength). Moves
/// only — it never doubles and always takes (the [BgAiPlayer] defaults).
class PubevalAiPlayer extends BgAiPlayer {
  @override
  String get name => 'Heuristic (pubeval)';

  @override
  String? get description =>
      "Tesauro's public-domain evaluator (~1650 FIBS strength)";

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async =>
      BgTurn(_bestTurn(position.board, position.onRoll, position.dice));

  // Depth-first over every legal turn (respecting the forced-move rules via
  // getForcedLegalMoves at each step), scoring each terminal board and keeping
  // the best move sequence. Returns an empty list for a dance.
  List<GammonMove> _bestTurn(
    List<List<int>> board,
    GammonPlayer player,
    List<int> dice,
  ) {
    var bestMoves = const <GammonMove>[];
    double? bestScore;

    void expand(
      List<List<int>> curBoard,
      List<int> curDice,
      List<GammonMove> moves,
    ) {
      final forced = GammonRules.getForcedLegalMoves(curBoard, player, curDice);
      if (forced.isEmpty) {
        // terminal: no more dice can be played -> score this board
        final score = PubEval.eval(curBoard, player);
        if (bestScore == null || score > bestScore!) {
          bestScore = score;
          bestMoves = moves;
        }
        return;
      }
      for (final moveList in forced.values) {
        for (final move in moveList) {
          final next = _copyBoard(curBoard);
          final deltas = GammonRules.applyMove(next, move); // mutates next
          if (deltas.isEmpty) continue;
          expand(next, _removeHops(curDice, move.hops), [...moves, move]);
        }
      }
    }

    expand(board, dice, const []);
    return bestMoves;
  }

  static List<List<int>> _copyBoard(List<List<int>> board) =>
      List<List<int>>.generate(board.length, (i) => List<int>.of(board[i]));

  static List<int> _removeHops(List<int> dice, List<int> hops) {
    final remaining = List<int>.of(dice);
    for (final hop in hops) {
      remaining.remove(hop.abs());
    }
    return remaining;
  }
}

/// Factory that builds [PubevalAiPlayer]s. Registered as a built-in.
class PubevalAiPlayerFactory extends BgAiPlayerFactory {
  @override
  String get name => 'Heuristic (pubeval)';

  @override
  String? get description =>
      "Tesauro's public-domain evaluator (~1650 FIBS strength)";

  @override
  BgAiPlayer create({String? level}) => PubevalAiPlayer();
}
