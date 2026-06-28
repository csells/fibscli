import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/fibs_play.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

FibsBoard parseBoard(String raw) {
  final m = CookieMonster()..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return FibsBoard.fromCrumbs(m.eatCookie(raw).crumbs!);
}

void main() {
  group('FibsPlay.legalMoveCommands (M2, from live data)', () {
    // Real frame captured live, just before BlunderBot_II (the player on roll)
    // played 13-9 9-7 with a roll of 4 and 2. This frame is MIRRORED relative
    // to the engine (player1Color != direction), so it exercises the
    // normalization end to end.
    const beforeBlunderMove =
        'board:BlunderBot_II:pompom:5:1:0:0:0:0:0:1:0:5:0:3:0:0:0:-4:4:-2:0'
        ':0:0:-3:-2:-2:-2:2:0:0:0:1:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:5:0:0';

    test('the frame is mirrored vs the engine', () {
      expect(parseBoard(beforeBlunderMove).isMirrored, isTrue);
    });

    test("reproduces the bot's real 13-9 9-7 move as a legal option", () {
      final fb = parseBoard(beforeBlunderMove);
      // the roll arrives after this board frame, so supply it explicitly
      final commands = FibsPlay.legalMoveCommands(fb, dice: const [4, 2]);
      expect(commands, contains('move 13-9 9-7'));
    });

    test('every generated command is well-formed and non-empty', () {
      final fb = parseBoard(beforeBlunderMove);
      final commands = FibsPlay.legalMoveCommands(fb, dice: const [4, 2]);
      expect(commands, isNotEmpty);
      for (final c in commands) {
        expect(c, startsWith('move '));
      }
    });

    test('fullTurnCommand spends both dice in one command', () {
      final fb = parseBoard(beforeBlunderMove);
      final cmd = FibsPlay.fullTurnCommand(fb, dice: const [4, 2])!;
      expect(cmd, startsWith('move '));
      final pairs = cmd.substring('move '.length).split(' ');
      expect(pairs.length, greaterThanOrEqualTo(2)); // both dice used
      for (final p in pairs) {
        expect(p, matches(RegExp(r'^(bar|off|\d+)-(bar|off|\d+)$')));
      }
    });
  });
}
