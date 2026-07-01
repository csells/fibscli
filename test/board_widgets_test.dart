import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pip_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // dice.dart: the die-face spot layout. A die showing N must have exactly N
  // pips, positioned within the 36x36 die.
  test('a die face has exactly as many spots as its value', () {
    for (var n = 1; n <= 6; n++) {
      final spots = DieLayout.spotsFor(n);
      expect(spots.length, n, reason: 'die $n should have $n spots');
      for (final s in spots) {
        expect(s.dx, inInclusiveRange(0, 36));
        expect(s.dy, inInclusiveRange(0, 36));
      }
    }
  });

  // pip_count.dart: the per-player pip-count readouts and their placement.
  test(
    'PipCountLayout.getLayouts reports each player pip count + position',
    () {
      final game = GammonState();
      final layouts = PipCountLayout.getLayouts(game);

      expect(layouts, hasLength(2));
      expect(layouts[0].pipCount, game.pipCountFor(GammonPlayer.one));
      expect(layouts[1].pipCount, game.pipCountFor(GammonPlayer.two));
      expect(layouts[0].pipCount, 167); // standard opening pip count
      expect(layouts[1].pipCount, 167);
      // player one's readout sits at the bottom tray, player two's at the top
      expect(layouts[0].top, greaterThan(layouts[1].top));
    },
  );

  testWidgets('PipCountView renders its pip count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PipCountView(
          layout: PipCountLayout(pipCount: 123, left: 0, top: 0),
        ),
      ),
    );
    expect(find.text('123'), findsOneWidget);
  });
}
