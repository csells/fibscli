import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GammonStats (issue #10)', () {
    test('records rolls, pips, and doubles', () {
      final stats = GammonStats();
      expect(stats.rolls, 0);
      expect(stats.pips, 0);
      expect(stats.doubles, 0);

      stats.record([3, 1]);
      expect(stats.rolls, 1);
      expect(stats.pips, 4);
      expect(stats.doubles, 0);

      stats.record([5, 5, 5, 5]); // doubles -> 4 dice
      expect(stats.rolls, 2);
      expect(stats.pips, 24);
      expect(stats.doubles, 1);
    });
  });

  group('GammonState stats (issue #10)', () {
    test('opening roll is recorded for the player on roll', () {
      final game = GammonState();
      final player = game.turnPlayer!;
      final stats = game.statsFor(player);

      expect(stats.rolls, 1);
      expect(stats.doubles, 0); // opening roll is never doubles
      expect(stats.pips, game.dice.fold<int>(0, (sum, d) => sum + d.roll));

      // the other player has not rolled yet
      expect(game.statsFor(GammonRules.otherPlayer(player)).rolls, 0);
    });

    test('committing a turn records a roll for the next player', () {
      final game = GammonState();
      final opener = game.turnPlayer!;
      game.commitTurn();
      final next = game.turnPlayer!;

      expect(next, isNot(opener));
      expect(game.statsFor(next).rolls, 1);
      expect(game.statsFor(next).pips,
          game.dice.fold<int>(0, (sum, d) => sum + d.roll));
    });
  });
}
