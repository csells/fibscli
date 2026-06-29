import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// player one (onRoll) all but home, player two stacked far back: a pure race
// player one wins almost surely.
Position _onRollDominatingRace() => Position(
  points: const [
    -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  oneOff: 14,
);

BgPosition _bg(Position p, GammonPlayer onRoll) =>
    BgPosition(board: p.toBoard(), onRoll: onRoll, dice: const []);

void main() {
  // the default cube policy lives on the base class, so EVERY engine inherits
  // real cube play; pubeval is the stand-in for "any moves-only engine".
  final ai = PubevalAiPlayer();

  group('BgAiPlayer.cubeDecision (default policy)', () {
    test('does not double on the even opening', () async {
      final action = await ai.cubeDecision(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: const [],
        ),
      );
      expect(action, BgCubeAction.noDouble);
    });

    test('offers a double when dominating', () async {
      final action = await ai.cubeDecision(
        _bg(_onRollDominatingRace(), GammonPlayer.one),
      );
      expect(action, BgCubeAction.offerDouble);
    });

    test('does not double when trailing badly', () async {
      final action = await ai.cubeDecision(
        _bg(_onRollDominatingRace(), GammonPlayer.two),
      );
      expect(action, BgCubeAction.noDouble);
    });
  });

  group('BgAiPlayer.respondToDouble (default policy)', () {
    test('passes a double from a dominating opponent', () async {
      // onRoll is the doubler (player one, dominating); we are player two and
      // should drop.
      final action = await ai.respondToDouble(
        _bg(_onRollDominatingRace(), GammonPlayer.one),
      );
      expect(action, BgCubeAction.pass);
    });

    test('takes a double in a playable position', () async {
      // the even opening is nowhere near a pass for the taker.
      final action = await ai.respondToDouble(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: const [],
        ),
      );
      expect(action, BgCubeAction.take);
    });
  });
}
