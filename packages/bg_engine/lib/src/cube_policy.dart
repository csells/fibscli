import 'dart:math';

import 'position.dart';
import 'race_eval.dart';
import 'rules.dart';

/// The single, pure doubling-cube policy shared by the game model and every AI
/// engine, so there is exactly one place that decides cube actions. Exact in a
/// pure race (via [RaceEval]); a pip-count heuristic with contact (via
/// [cubeAction] over [raceWinProbability]). These two heuristics live here --
/// beside their only consumer -- rather than masquerading as hard rules in
/// [GammonRules].
class CubePolicy {
  CubePolicy._();

  /// Estimate the probability that the player on roll wins a race, given both
  /// pip counts (issue #14). This is a heuristic, NOT an equity engine: a
  /// logistic model of the pip lead, widened by the size of the race (variance
  /// grows with pip count) and nudged by a small on-roll bonus. Good enough to
  /// guide cube decisions in a pure race; it does not account for contact,
  /// wastage, or gammons.
  static double raceWinProbability({
    required int myPips,
    required int oppPips,
  }) {
    const onRollBonus = 4.0; // ~half an average roll for moving next
    final total = (myPips + oppPips).toDouble();
    final spread = sqrt(total < 1 ? 1 : total) * 1.5;
    final adjustedLead = (oppPips - myPips) + onRollBonus;
    return 1.0 / (1.0 + exp(-adjustedLead / spread));
  }

  /// The recommended cube action for the player on roll given their win
  /// probability (issue #14). Uses the classic cubeless money-game reference
  /// points: a take point of 25% (so the opponent passes once the doubler is
  /// above ~75%) and a doubling window that opens around 70%.
  static CubeAction cubeAction(double winProbability) {
    const doublePoint = 0.70;
    const passPoint = 0.75;
    if (winProbability < doublePoint) return CubeAction.noDouble;
    if (winProbability <= passPoint) return CubeAction.doubleTake;
    return CubeAction.doublePass;
  }

  /// Cubeless probability that [onRoll] wins from [board]. Exact in a pure
  /// race, otherwise the pip-count heuristic.
  static double winProbability(List<List<int>> board, GammonPlayer onRoll) {
    final exact = RaceEval.winProbabilityOrNull(board, onRoll);
    if (exact != null) return exact;
    final position = Position.fromBoard(board);
    return raceWinProbability(
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
        cubeAction(winProbability(board, onRoll));
  }
}
