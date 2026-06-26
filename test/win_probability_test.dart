import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GammonRules.raceWinProbability (issue #14)', () {
    double wp(int my, int opp) =>
        GammonRules.raceWinProbability(myPips: my, oppPips: opp);

    test('always returns a probability strictly between 0 and 1', () {
      for (final pair in [
        [167, 167],
        [30, 150],
        [150, 30],
        [1, 1],
      ]) {
        final p = wp(pair[0], pair[1]);
        expect(p, greaterThan(0));
        expect(p, lessThan(1));
      }
    });

    test('the player on roll has an edge in an even race', () {
      final p = wp(100, 100);
      expect(p, greaterThan(0.5));
      expect(p, lessThan(0.65));
    });

    test('a bigger lead means a higher win probability', () {
      expect(wp(70, 100), greaterThan(wp(100, 100)));
      expect(wp(100, 100), greaterThan(wp(100, 70)));
    });

    test('a dominant lead is near-certain and a deep deficit near-hopeless',
        () {
      expect(wp(30, 150), greaterThan(0.95));
      expect(wp(150, 30), lessThan(0.05));
    });
  });

  group('GammonRules.cubeAction (issue #14)', () {
    test('too early to double below the doubling window', () {
      expect(GammonRules.cubeAction(0.5), CubeAction.noDouble);
      expect(GammonRules.cubeAction(0.69), CubeAction.noDouble);
    });

    test('inside the window: double and opponent takes', () {
      expect(GammonRules.cubeAction(0.72), CubeAction.doubleTake);
    });

    test('past the take point: double and opponent should pass', () {
      expect(GammonRules.cubeAction(0.9), CubeAction.doublePass);
    });
  });

  group('GammonState.winProbabilityFor (issue #14)', () {
    test('the two players probabilities are complementary', () {
      final game = GammonState();
      final onRoll = game.turnPlayer!;
      final other = GammonRules.otherPlayer(onRoll);
      final pa = game.winProbabilityFor(onRoll);
      final pb = game.winProbabilityFor(other);

      expect(pa, greaterThan(0.5)); // on-roll edge on the symmetric start
      expect(pb, lessThan(0.5));
      expect(pa + pb, closeTo(1.0, 1e-9));
    });
  });
}
