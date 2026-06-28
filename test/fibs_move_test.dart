import 'package:fibscli/fibs_move.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fibsMoveCommand (milestone 2)', () {
    test('matches a real captured X move (BlunderBot 13-9 9-7)', () {
      // validated live: this is exactly what FIBS reported for the move
      final move = GammonMove(fromPipNo: 13, toPipNo: 7, hops: const [-4, -2]);
      expect(fibsMoveCommand(move), 'move 13-9 9-7');
    });

    test('matches a real captured O move (pompom 1-7 7-11)', () {
      final move = GammonMove(fromPipNo: 1, toPipNo: 11, hops: const [6, 4]);
      expect(fibsMoveCommand(move), 'move 1-7 7-11');
    });

    test('single-hop move', () {
      final move = GammonMove(fromPipNo: 8, toPipNo: 5, hops: const [-3]);
      expect(fibsMoveCommand(move), 'move 8-5');
    });

    test('bearing off uses the off keyword', () {
      // player1 (X) bears off from the 3 point exactly
      final move = GammonMove(fromPipNo: 3, toPipNo: 0, hops: const [-3]);
      expect(fibsMoveCommand(move), 'move 3-off');
    });

    test('overshooting a bear-off still says off', () {
      // X on the 2 point with a 5: overshoots to off
      final move = GammonMove(fromPipNo: 2, toPipNo: 0, hops: const [-5]);
      expect(fibsMoveCommand(move), 'move 2-off');
    });

    test('player2 (O) bears off to the 25 end', () {
      final move = GammonMove(fromPipNo: 23, toPipNo: 25, hops: const [2]);
      expect(fibsMoveCommand(move), 'move 23-off');
    });

    test('entering from the bar uses the bar keyword', () {
      // player1 (X) enters from the bar (pip 25) with a 3
      final move = GammonMove(fromPipNo: 25, toPipNo: 22, hops: const [-3]);
      expect(fibsMoveCommand(move), 'move bar-22');
    });

    test('player2 (O) enters from the bar (pip 0)', () {
      final move = GammonMove(fromPipNo: 0, toPipNo: 4, hops: const [4]);
      expect(fibsMoveCommand(move), 'move bar-4');
    });
  });

  group('fibsRawMove (tap-to-move, milestone 2)', () {
    test('a plain point-to-point move', () {
      expect(fibsRawMove(13, 9, GammonPlayer.one), 'move 13-9');
    });

    test('X bar/off keywords', () {
      expect(fibsRawMove(25, 22, GammonPlayer.one), 'move bar-22'); // X bar=25
      expect(fibsRawMove(3, 0, GammonPlayer.one), 'move 3-off'); //    X off=0
    });

    test('O bar/off keywords', () {
      expect(fibsRawMove(0, 4, GammonPlayer.two), 'move bar-4'); //    O bar=0
      expect(fibsRawMove(22, 25, GammonPlayer.two), 'move 22-off'); // O off=25
    });
  });
}
