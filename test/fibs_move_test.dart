import 'package:fibscli/fibs_move.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

// A one-move turn goes through the same _hopPairs path as a multi-move turn;
// these single-move cases cover the bar/off/overshoot rendering.
String _one(GammonMove move) => fibsTurnCommand([move]);

void main() {
  group('fibsTurnCommand (whole turn submitted at once)', () {
    test('joins several moves into one command', () {
      final moves = [
        GammonMove(fromPipNo: 8, toPipNo: 4, hops: const [-4]),
        GammonMove(fromPipNo: 6, toPipNo: 4, hops: const [-2]),
      ];
      expect(fibsTurnCommand(moves), 'move 8-4 6-4');
    });

    test('expands a multi-hop move and keeps bar/off keywords', () {
      final moves = [
        GammonMove(fromPipNo: 13, toPipNo: 7, hops: const [-4, -2]),
        GammonMove(fromPipNo: 3, toPipNo: 0, hops: const [-3]), // bear off
      ];
      expect(fibsTurnCommand(moves), 'move 13-9 9-7 3-off');
    });

    test('an empty turn (a dance) is just "move"', () {
      expect(fibsTurnCommand(const []), 'move');
    });

    // single-move renderings (bar/off/overshoot edge cases)
    test('a real captured X move (BlunderBot 13-9 9-7)', () {
      final move = GammonMove(fromPipNo: 13, toPipNo: 7, hops: const [-4, -2]);
      expect(_one(move), 'move 13-9 9-7');
    });

    test('overshooting a bear-off still says off', () {
      // X on the 2 point with a 5: overshoots to off
      final move = GammonMove(fromPipNo: 2, toPipNo: 0, hops: const [-5]);
      expect(_one(move), 'move 2-off');
    });

    test('player2 (O) bears off to the 25 end', () {
      final move = GammonMove(fromPipNo: 23, toPipNo: 25, hops: const [2]);
      expect(_one(move), 'move 23-off');
    });

    test('entering from the bar uses the bar keyword (X bar=25)', () {
      final move = GammonMove(fromPipNo: 25, toPipNo: 22, hops: const [-3]);
      expect(_one(move), 'move bar-22');
    });

    test('player2 (O) enters from the bar (pip 0)', () {
      final move = GammonMove(fromPipNo: 0, toPipNo: 4, hops: const [4]);
      expect(_one(move), 'move bar-4');
    });
  });
}
