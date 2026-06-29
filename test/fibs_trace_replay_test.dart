// State-level trace replay: feed a real captured game (the same fixture the
// move-legality replay uses) through the NEW FibsSession reducer and the board
// rendering, asserting invariants at every step. This cross-checks the reducer
// + FibsBoard.toGammonState against real FIBS data: no checker is ever lost in
// translation, the derived turn matches the wire, and the roll/move guards stay
// mutually consistent.

import 'dart:io';

import 'package:fibscli/fibs_session.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

// Parse a logged `FibsCookie.FIBS_Board  {k: v, ...}` line into board crumbs.
Map<String, String>? _boardCrumbs(String line) {
  if (!line.contains('FIBS_Board')) return null;
  final lb = line.indexOf('{');
  final rb = line.lastIndexOf('}');
  if (lb < 0 || rb < 0) return null;
  final m = <String, String>{};
  for (final part in line.substring(lb + 1, rb).split(', ')) {
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

Map<String, String>? _youRollCrumbs(String line) {
  if (!line.contains('FIBS_YouRoll')) return null;
  final d1 = RegExp(r'die1: (\d+)').firstMatch(line);
  final d2 = RegExp(r'die2: (\d+)').firstMatch(line);
  if (d1 == null || d2 == null) return null;
  return {'die1': d1.group(1)!, 'die2': d2.group(1)!};
}

CookieMessage _cm(FibsCookie cookie, Map<String, String> crumbs) =>
    CookieMessage(cookie, '', crumbs, CookieMonsterState.FIBS_RUN_STATE);

void main() {
  test('the captured game replays through the reducer with no lost '
      'checkers', () {
    final lines = File(
      'test/fixtures/game_trace_sample.txt',
    ).readAsLinesSync().where((l) => l.trim().isNotEmpty);

    var session = const FibsSession(user: 'You'); // player1 is "You" in-trace
    var boards = 0;

    for (final line in lines) {
      final board = _boardCrumbs(line);
      final roll = _youRollCrumbs(line);
      if (board != null) {
        session = session.reduce(_cm(FibsCookie.FIBS_Board, board));
        boards++;

        // every rendered state conserves all 30 checkers across both sides
        final rendered = session.gameState!.board;
        final position = Position.fromBoard(rendered);
        expect(position.totalFor(GammonPlayer.one), 15, reason: line);
        expect(position.totalFor(GammonPlayer.two), 15, reason: line);

        // the derived turn matches the wire's turnColor (-1 X, 1 O, 0 over)
        final turnColor = int.parse(board['turnColor']!);
        final expectedTurn = turnColor == -1
            ? GammonPlayer.one
            : turnColor == 1
            ? GammonPlayer.two
            : null;
        expect(session.board!.turnPlayer, expectedTurn, reason: line);

        // the action guards can never both be open at once
        expect(session.canRoll && session.canMoveNow, isFalse, reason: line);
      } else if (roll != null) {
        session = session.reduce(_cm(FibsCookie.FIBS_YouRoll, roll));

        // a YouRoll always proves it's our turn and gives us those dice to play
        final d1 = int.parse(roll['die1']!);
        final d2 = int.parse(roll['die2']!);
        final expected = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
        expect(session.isMyTurn, isTrue, reason: line);
        expect(session.effectiveDice, expected, reason: line);
      }
    }

    expect(
      boards,
      greaterThan(10),
      reason: 'the fixture should be substantial',
    );
  });
}
