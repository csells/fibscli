// OFFLINE legality replay: take the (board -> our dice) pairs captured from a
// real live game (test/fixtures/game_trace_sample.txt) and, for each of our
// turns, run the REAL engine's FibsPlay.bestTurnCommand and INDEPENDENTLY
// validate the produced FIBS `move` command directly in FIBS coordinates (no
// server, no shared engine code). Any move that lands on a point blocked by 2+
// opponent checkers, or that uses dice we didn't roll, is a bug. This guards
// against regressions in move generation / coordinate translation across a
// broad set of real positions.
//
// The fixture is the board/roll lines from a recorded BlunderBot game; refresh
// it by capturing a new trace with the live e2e (test/fibs_live_e2e_test.dart).

import 'dart:io';

import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/fibs_play.dart';
import 'package:flutter_test/flutter_test.dart';

// Parse a logged `FibsCookie.FIBS_Board  {k: v, ...}` line back into crumbs.
Map<String, String>? _boardCrumbs(String line) {
  if (!line.contains('FIBS_Board')) return null;
  final lb = line.indexOf('{');
  final rb = line.lastIndexOf('}');
  if (lb < 0 || rb < 0) return null;
  final body = line.substring(lb + 1, rb);
  final m = <String, String>{};
  for (final part in body.split(', ')) {
    final i = part.indexOf(': ');
    if (i < 0) continue;
    m[part.substring(0, i)] = part.substring(i + 2);
  }
  return {
    'board': m['board']!,
    'turnColor': m['turnColor']!,
    'player1Color': m['player1Color']!,
    'direction': m['direction']!,
    'player1Dice': m['player1Dice']!.replaceAll(' ', ''),
    'player2Dice': m['player2Dice']!.replaceAll(' ', ''),
    'doublingCube': m['doublingCube']!,
    'player1Home': m['player1Home']!,
    'player2Home': m['player2Home']!,
    'player1Bar': m['player1Bar']!,
    'player2Bar': m['player2Bar']!,
    'player1': m['player1']!,
    'player2': m['player2']!,
    'canMove': m['canMove']!,
  };
}

List<int>? _youRoll(String line) {
  if (!line.contains('FIBS_YouRoll')) return null;
  final d1 = RegExp(r'die1: (\d+)').firstMatch(line);
  final d2 = RegExp(r'die2: (\d+)').firstMatch(line);
  if (d1 == null || d2 == null) return null;
  final a = int.parse(d1.group(1)!);
  final b = int.parse(d2.group(1)!);
  return a == b ? [a, a, a, a] : [a, b];
}

// Independent FIBS-frame legality check of a `move a-b c-d ...` command. We are
// "You" == player1; OUR checkers are the sign matching player1Color, OPPONENT's
// the other sign. A destination is BLOCKED if it holds 2+ opponent checkers.
// Returns a failure reason, or null if the whole command is legal.
String? _validate(FibsBoard fb, List<int> dice, String command) {
  final pts = List<int>.of(fb.points); // 0..25, FIBS frame
  final us = fb.player1Color; // +1 or -1: sign of our checkers
  // bar/off cells depend on DIRECTION of travel, not color: a player moving
  // 24->1 (direction -1) enters from cell 25 and bears off at cell 0.
  final barCell = fb.direction == -1 ? 25 : 0;
  final offCell = fb.direction == -1 ? 0 : 25;
  final remaining = List<int>.of(dice);

  final parts = command.substring('move '.length).split(' ');
  for (final hop in parts) {
    final fromTo = hop.split('-');
    final fromS = fromTo[0];
    final toS = fromTo[1];
    final from = fromS == 'bar' ? barCell : int.parse(fromS);
    final to =
        toS == 'off' ? offCell : (toS == 'bar' ? barCell : int.parse(toS));

    final fromCount = pts[from];
    final haveOurs = us == 1 ? fromCount > 0 : fromCount < 0;
    if (!haveOurs) return 'no checker at $fromS (cell=$fromCount) for $command';

    final isBearOff = toS == 'off';
    // die used = pip distance traveled; bear-off allows overshoot from the
    // highest point, so don't enforce exact-die availability there.
    final die = (from - to).abs();
    if (!isBearOff && !remaining.remove(die)) {
      return 'die $die not available (have $remaining) for $hop in $command';
    }
    if (!isBearOff) {
      final destOpp = us == 1 ? -pts[to] : pts[to]; // opponent count at `to`
      if (destOpp >= 2) {
        return 'BLOCKED: $hop lands on point $to held by $destOpp opp '
            '(board=${fb.points}, dice=$dice, cmd=$command)';
      }
      if (destOpp == 1) pts[to] = 0; // hit: opponent blot to bar (not modeled)
      pts[to] += us;
    }
    pts[from] -= us;
  }
  return null;
}

void main() {
  test('every move the engine generates for real positions is legal', () {
    final lines = File('test/fixtures/game_trace_sample.txt').readAsLinesSync();

    var ourTurns = 0;
    var dances = 0;
    final failures = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final crumbs = _boardCrumbs(lines[i]);
      if (crumbs == null) continue;
      final fb = FibsBoard.fromCrumbs(crumbs);
      if (fb.player1Name != 'You') continue; // our own game
      if (fb.turnColor != fb.player1Color) continue; // our turn

      var dice = fb.activeDice;
      if (dice.isEmpty) {
        for (var j = i + 1; j < lines.length; j++) {
          if (_boardCrumbs(lines[j]) != null) break;
          final r = _youRoll(lines[j]);
          if (r != null) {
            dice = r;
            break;
          }
        }
      }
      if (dice.isEmpty) continue;

      ourTurns++;
      final cmd = FibsPlay.bestTurnCommand(fb, dice: dice) ??
          FibsPlay.fullTurnCommand(fb, dice: dice);
      if (cmd == null) {
        dances++; // engine found no legal move -> we'd correctly send nothing
        continue;
      }
      final reason = _validate(fb, dice, cmd);
      if (reason != null) failures.add(reason);
    }

    expect(ourTurns, greaterThan(20),
        reason: 'fixture should exercise many of our turns (got $ourTurns)');
    expect(failures, isEmpty,
        reason: 'replayed $ourTurns turns ($dances dances); illegal moves:\n'
            '${failures.join("\n")}');
  });
}
