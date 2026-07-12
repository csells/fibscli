import '../pubeval.dart';
import 'bg_ai_player.dart';
import 'turn_search.dart';

/// The out-of-the-box heuristic AI: enumerates every legal full turn from the
/// position and plays the one whose resulting board the [PubEval] evaluator
/// scores highest from the mover's perspective (~1650 FIBS strength). Moves
/// only — it never doubles and always takes (the [BgAiPlayer] defaults).
class PubevalAiPlayer extends BgAiPlayer {
  /// Creates the player; [name] and [description] label it in the UI (an app
  /// can present the same evaluator under its own persona).
  PubevalAiPlayer({
    this.name = 'Heuristic (pubeval)',
    this.description = "Tesauro's public-domain evaluator",
  });

  /// The opponent's UI label.
  @override
  final String name;

  /// The opponent's UI caption.
  @override
  final String? description;

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async {
    final turns = enumerateLegalTurns(
      position.board,
      position.onRoll,
      position.dice,
    );
    if (turns.isEmpty) return const BgTurn([]);
    var best = turns.first;
    var bestScore = PubEval.eval(best.board, position.onRoll);
    for (final turn in turns.skip(1)) {
      final score = PubEval.eval(turn.board, position.onRoll);
      if (score > bestScore) {
        bestScore = score;
        best = turn;
      }
    }
    return BgTurn(best.moves);
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
