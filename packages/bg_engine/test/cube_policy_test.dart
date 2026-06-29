import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// player one (onRoll) is all but home with a single checker on the ace point;
// player two is stacked far back -- a pure race player one wins almost surely.
Position _onRollDominatingRace() => Position(
  points: const [
    -1, // point 1: player one's last checker (1 pip to go)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    15, // point 13: all 15 of player two's checkers (12 pips each)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  oneOff: 14,
);

void main() {
  group('Position.pipCountFor', () {
    test('the standard opening is 167 pips a side', () {
      final p = Position.standard();
      expect(p.pipCountFor(GammonPlayer.one), 167);
      expect(p.pipCountFor(GammonPlayer.two), 167);
    });

    test('a checker on the bar counts a full 25 pips', () {
      final p = Position(points: List<int>.filled(24, 0), oneBar: 1);
      expect(p.pipCountFor(GammonPlayer.one), 25);
    });
  });

  group('CubePolicy.winProbability', () {
    test('the player on roll has the edge on the even opening', () {
      final p = CubePolicy.winProbability(
        GammonRules.initialBoard(),
        GammonPlayer.one,
      );
      expect(p, greaterThan(0.5));
      expect(p, lessThan(0.65));
    });

    test('a dominating race is near-certain for the player on roll', () {
      final board = _onRollDominatingRace().toBoard();
      expect(
        CubePolicy.winProbability(board, GammonPlayer.one),
        greaterThan(0.95),
      );
    });
  });

  group('CubePolicy.recommendedAction', () {
    test('the even opening is too early to double', () {
      expect(
        CubePolicy.recommendedAction(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
        ),
        CubeAction.noDouble,
      );
    });

    test('a dominating race is a double the opponent should pass', () {
      expect(
        CubePolicy.recommendedAction(
          board: _onRollDominatingRace().toBoard(),
          onRoll: GammonPlayer.one,
        ),
        CubeAction.doublePass,
      );
    });

    test('the trailing player in that race never doubles', () {
      expect(
        CubePolicy.recommendedAction(
          board: _onRollDominatingRace().toBoard(),
          onRoll: GammonPlayer.two,
        ),
        CubeAction.noDouble,
      );
    });

    test('a maxed cube is never doubled', () {
      expect(
        CubePolicy.recommendedAction(
          board: _onRollDominatingRace().toBoard(),
          onRoll: GammonPlayer.one,
          cubeValue: DoublingCube.maxValue,
        ),
        CubeAction.noDouble,
      );
    });

    test('a cube the opponent owns is never doubled by us', () {
      expect(
        CubePolicy.recommendedAction(
          board: _onRollDominatingRace().toBoard(),
          onRoll: GammonPlayer.one,
          cubeValue: 2,
          cubeOwner: GammonPlayer.two, // opponent holds it
        ),
        CubeAction.noDouble,
      );
    });
  });
}
