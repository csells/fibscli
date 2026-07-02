import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

// player two on roll with one checker left to bear off; player one far back.
GammonState _aiDominatingGame() {
  final position = Position(
    points: const [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -15, // point 12: all 15 of player one's checkers, far back
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      1, // point 24: player two's last checker (1 pip to go)
    ],
    twoOff: 14,
  );
  return GammonState.from(
    board: position.toBoard(),
    dice: [DieState(3), DieState(1)],
    turnPlayer: GammonPlayer.two,
  );
}

void main() {
  group('GammonState.winner', () {
    test('is null while the game is in progress', () {
      final game = GammonState();
      expect(game.gameOver, isFalse);
      expect(game.winner, isNull);
    });

    test('is the bearer-off once all 15 checkers are off', () {
      final game = _aiDominatingGame()..autoBearOff();
      expect(game.gameOver, isTrue);
      expect(game.winner, GammonPlayer.two);
    });

    test('is the doubler when the opponent declines the double', () {
      final game = GammonState();
      final doubler = game.turnPlayer!;
      game.declineDouble();
      expect(game.gameOver, isTrue);
      expect(game.winner, doubler);
    });
  });

  group('GammonState.resign', () {
    test('ends the game with the opponent as winner', () {
      final game = GammonState();
      final resigner = game.turnPlayer!;
      game.resign(resigner);
      expect(game.gameOver, isTrue);
      expect(game.winner, GammonRules.otherPlayer(resigner));
    });

    test('notifies listeners', () {
      final game = GammonState();
      var notified = false;
      game.addListener(() => notified = true);
      game.resign(game.turnPlayer!);
      expect(notified, isTrue);
    });

    test('throws once the game is over', () {
      final game = GammonState()..declineDouble();
      expect(() => game.resign(GammonPlayer.one), throwsException);
    });
  });
}
