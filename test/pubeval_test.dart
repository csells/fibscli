import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/fibs_play.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fibs_board_test.dart' show fibsBoardLine;

FibsBoard parse(String raw) {
  final m = CookieMonster()..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return FibsBoard.fromCrumbs(m.eatCookie(raw).crumbs!);
}

// helper: an engine-canonical board from a {pip: signedCount} spec, negative =
// player1/X, positive = player2/O (matches the engine's id convention via sign)
List<List<int>> boardFrom(Map<int, int> spec) {
  final b = List<List<int>>.generate(26, (_) => <int>[]);
  var nx = 0;
  var no = 0;
  spec.forEach((pip, count) {
    for (var i = 0; i < count.abs(); i++) {
      if (count < 0) {
        nx += 1;
        b[pip].add(-nx);
      } else {
        no += 1;
        b[pip].add(no);
      }
    }
  });
  return b;
}

void main() {
  group('pubeval weight tables', () {
    test('both weight vectors have exactly 122 entries', () {
      expect(PubEval.raceWeights.length, 122);
      expect(PubEval.contactWeights.length, 122);
    });
  });

  group('pubeval.isRace', () {
    test('opening position is contact (not a race)', () {
      // standard opening, no one borne in; back checkers still engaged
      final b = boardFrom({
        6: 5, 8: 3, 13: 5, 24: 2, // O (positive)
        19: -5, 17: -3, 12: -5, 1: -2, // X (negative)
      });
      expect(PubEval.isRace(b), isFalse);
    });

    test('fully disengaged home boards are a race', () {
      // O all on 19-24, X all on 1-6: cannot contact
      final b = boardFrom({19: 8, 20: 7, 6: -8, 5: -7});
      expect(PubEval.isRace(b), isTrue);
    });

    test('a checker on the bar is always contact', () {
      // O on the bar (engine index 0)
      final b = boardFrom({19: 8, 20: 6, 0: 1, 6: -8, 5: -7});
      expect(PubEval.isRace(b), isFalse);
    });
  });

  group('pubeval move selection', () {
    test('prefers hitting an opponent blot (via FibsPlay.bestTurnCommand)', () {
      // O on roll on pip 1; X blot on pip 7; a 6 plays 1-7 and hits.
      final pts = List<int>.filled(26, 0);
      pts[1] = 1; //   O blot, on roll
      pts[7] = -1; //  X blot O can hit with a 6
      pts[13] = 5; //  O bulk
      pts[19] = -5; // X bulk
      final fb = parse(fibsBoardLine(pts, turn: 1, oDice: [6, 3]));
      final cmd = FibsPlay.bestTurnCommand(fb)!;
      expect(cmd, contains('1-7')); // takes the hit
    });

    test('a position with our checkers off scores higher than without', () {
      // borne-off men are pure progress; more off must score better for us
      final some = boardFrom({25: 10, 24: 3, 23: 2}); // O: 10 off, 5 on board
      final more = boardFrom({25: 13, 24: 2}); //        O: 13 off, 2 on board
      expect(
        PubEval.eval(more, GammonPlayer.two),
        greaterThan(PubEval.eval(some, GammonPlayer.two)),
      );
    });

    test('all fifteen men off is the winning sentinel', () {
      final won = boardFrom({25: 15});
      expect(PubEval.eval(won, GammonPlayer.two), greaterThan(1e7));
    });
  });
}
