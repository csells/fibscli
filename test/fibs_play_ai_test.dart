import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/fibs_play.dart';
import 'package:fibscli/model.dart'; // PubevalAiPlayer/BgAiPlayer via re-export
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fibs_board_test.dart' show fibsBoardLine;

FibsBoard _parse(String raw) {
  final m = CookieMonster()..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return FibsBoard.fromCrumbs(m.eatCookie(raw).crumbs!);
}

// O on roll on pip 1; X blot on pip 7; a 6 plays 1-7 and hits.
FibsBoard _hitPosition() {
  final pts = List<int>.filled(26, 0);
  pts[1] = 1; // O blot, on roll
  pts[7] = -1; // X blot O can hit with a 6
  pts[13] = 5; // O bulk
  pts[19] = -5; // X bulk
  return _parse(fibsBoardLine(pts, turn: 1, oDice: [6, 3]));
}

void main() {
  test(
    'bestTurnCommandWithAi routes FIBS selection through a BgAiPlayer',
    () async {
      final cmd = await FibsPlay.bestTurnCommandWithAi(
        _hitPosition(),
        PubevalAiPlayer(),
      );
      expect(cmd, isNotNull);
      expect(cmd, startsWith('move '));
      expect(cmd, contains('1-7')); // the pubeval-routed turn takes the hit
    },
  );

  test('agrees with the direct pubeval path on taking the hit', () async {
    final fb = _hitPosition();
    final viaAi = await FibsPlay.bestTurnCommandWithAi(fb, PubevalAiPlayer());
    final viaDirect = FibsPlay.bestTurnCommand(fb);
    // both are pubeval, so both hit; the chosen hit move appears in each
    expect(viaDirect, contains('1-7'));
    expect(viaAi, contains('1-7'));
  });

  test('returns null when there are no dice to play', () async {
    final cmd = await FibsPlay.bestTurnCommandWithAi(
      _hitPosition(),
      PubevalAiPlayer(),
      dice: const [],
    );
    expect(cmd, isNull);
  });
}
