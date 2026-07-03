import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoublingCube (issue #12)', () {
    test('starts centered at 1, either player may double', () {
      final cube = DoublingCube();
      expect(cube.value, 1);
      expect(cube.owner, isNull);
      expect(cube.canDoubleBy(GammonPlayer.one), isTrue);
      expect(cube.canDoubleBy(GammonPlayer.two), isTrue);
    });

    test('taking a double doubles the value and transfers ownership', () {
      final cube = DoublingCube()..applyTake(GammonPlayer.one); // two takes
      expect(cube.value, 2);
      expect(cube.owner, GammonPlayer.two);
      expect(cube.canDoubleBy(GammonPlayer.two), isTrue);
      expect(cube.canDoubleBy(GammonPlayer.one), isFalse);
    });

    test('value caps at 64', () {
      final cube = DoublingCube();
      var offeredBy = GammonPlayer.one;
      for (var i = 0; i != 6; ++i) {
        cube.applyTake(offeredBy);
        offeredBy = cube.owner!; // current owner offers next
      }
      expect(cube.value, 64);
      expect(cube.canDoubleBy(cube.owner!), isFalse);
    });
  });

  group('GammonState doubling (issue #12)', () {
    test('player on roll may offer a double before moving', () {
      final game = GammonState.from(
        board: GammonRules.initialBoard(),
        dice: const [],
        turnPlayer: GammonPlayer.one,
      );
      final player = game.turnPlayer!;
      expect(game.canOfferDouble(player), isTrue);
      expect(game.canOfferDouble(GammonRules.otherPlayer(player)), isFalse);
    });

    test('rolled dice cannot be doubled', () {
      final game = GammonState();
      final player = game.turnPlayer!;
      expect(game.dice, isNotEmpty);
      expect(game.canOfferDouble(player), isFalse);
    });

    test('accepting a double updates the cube and continues play', () {
      final game = GammonState.from(
        board: GammonRules.initialBoard(),
        dice: const [],
        turnPlayer: GammonPlayer.one,
      );
      final doubler = game.turnPlayer!;
      game.acceptDouble();
      expect(game.cube.value, 2);
      expect(game.cube.owner, GammonRules.otherPlayer(doubler));
      expect(game.gameOver, isFalse);
    });

    test('declining a double ends the game for the doubler', () {
      final game = GammonState.from(
        board: GammonRules.initialBoard(),
        dice: const [],
        turnPlayer: GammonPlayer.one,
      );
      final doubler = game.turnPlayer!;
      game.declineDouble();
      expect(game.gameOver, isTrue);
      // winner is derived from turnPlayer, which stays the doubler
      expect(game.turnPlayer, doubler);
    });

    test('a committed turn can pause before the next roll', () {
      final game = GammonState();
      final opener = game.turnPlayer!;

      game.commitTurn(roll: false);

      expect(game.turnPlayer, GammonRules.otherPlayer(opener));
      expect(game.dice, isEmpty);
      expect(game.canRoll, isTrue);
      expect(game.canOfferDouble(game.turnPlayer), isTrue);

      game.rollTurn();

      expect(game.dice, isNotEmpty);
      expect(game.canRoll, isFalse);
      expect(game.canOfferDouble(game.turnPlayer), isFalse);
    });
  });
}
