import 'position.dart';
import 'race_eval.dart';
import 'rules.dart';

/// The single, pure doubling-cube policy shared by the game model and every AI
/// engine, so there is exactly one place that decides cube actions. Exact in a
/// pure race (via [RaceEval]); a pip-count heuristic with contact (via
/// [GammonRules.cubeAction] over [GammonRules.raceWinProbability]).
class CubePolicy {
  CubePolicy._();

  /// Cubeless probability that [onRoll] wins from [board]. Exact in a pure
  /// race, otherwise the pip-count heuristic.
  static double winProbability(List<List<int>> board, GammonPlayer onRoll) {
    final exact = RaceEval.winProbabilityOrNull(board, onRoll);
    if (exact != null) return exact;
    final position = Position.fromBoard(board);
    return GammonRules.raceWinProbability(
      myPips: position.pipCountFor(onRoll),
      oppPips: position.pipCountFor(GammonRules.otherPlayer(onRoll)),
    );
  }

  /// The recommended cube action for [onRoll] given the cube state. Returns
  /// [CubeAction.noDouble] once the cube is maxed or the opponent owns it (you
  /// can only double a cube you hold or that is centered).
  static CubeAction recommendedAction({
    required List<List<int>> board,
    required GammonPlayer onRoll,
    int cubeValue = 1,
    GammonPlayer? cubeOwner,
  }) {
    if (cubeValue >= DoublingCube.maxValue) return CubeAction.noDouble;
    if (cubeOwner != null && cubeOwner != onRoll) return CubeAction.noDouble;
    return RaceEval.cubeActionOrNull(board, onRoll, cubeOwner) ??
        GammonRules.cubeAction(winProbability(board, onRoll));
  }
}
