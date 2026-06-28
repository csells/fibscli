import 'dart:async';

import 'package:fibscli/fibs_bot_player.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game; player1 is the literal "You". turn '1' = our turn.
String boardLine({String turn = '1', String p1dice = '0:0'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

String whoInfo(String name, {required String client, int rating = 1500}) =>
    '5 $name - - 1 0 $rating.00 1000 0 1234567890 host $client -';

Future<FibsBotPlayer> _player(FakeTransport fake, {int targetWins = 2}) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'me', pass: 'x');
  return FibsBotPlayer(
    fibs,
    pace: () async {}, // no human delay in tests
    targetWins: targetWins,
  );
}

void main() {
  test('resumes a saved match before inviting a fresh one', () async {
    final fake = FakeTransport();
    final player = await _player(fake);
    unawaited(player.run());

    fake.feed('  BlunderBot 0 0 - 1'); // a saved-games listing line
    await pumpEventQueue();

    // resume == a bare `invite <opp>` (no match length), not a new match
    expect(fake.sent, contains('invite BlunderBot'));
    expect(fake.sent, isNot(contains('invite BlunderBot 1')));
    player.stop('test');
  });

  test('invites a weak BlunderBot when one is free', () async {
    final fake = FakeTransport();
    final player = await _player(fake);
    unawaited(player.run());

    fake.feed(whoInfo('BlunderBot', client: 'ParlorBot', rating: 1555));
    fake.feed('6'); // CLIP_WHO_END: the login who-list has finished
    await pumpEventQueue();

    expect(fake.sent, contains('invite BlunderBot 1'));
    player.stop('test');
  });

  test(
    'never invites a strong bot — asks for the who-list and waits',
    () async {
      final fake = FakeTransport();
      final player = await _player(fake);
      unawaited(player.run());

      fake.feed(whoInfo('wildbg', client: 'bot_1p_matches_only', rating: 1835));
      fake.feed('6'); // CLIP_WHO_END
      await pumpEventQueue();

      expect(fake.sent.where((c) => c.startsWith('invite')), isEmpty);
      expect(fake.sent, contains('who'));
      player.stop('test');
    },
  );

  test('rolls when it is our turn with no dice', () async {
    final fake = FakeTransport();
    final player = await _player(fake);
    unawaited(player.run());

    fake.feed(boardLine(p1dice: '0:0'));
    await pumpEventQueue();

    expect(fake.sent, contains('roll'));
    player.stop('test');
  });

  test('plays a full-turn move when it is our turn with dice', () async {
    final fake = FakeTransport();
    final player = await _player(fake);
    unawaited(player.run());

    fake.feed(boardLine(p1dice: '3:1'));
    await pumpEventQueue();

    expect(fake.sent.any((c) => c.startsWith('move ')), isTrue);
    player.stop('test');
  });

  test('completes after reaching the target number of wins', () async {
    final fake = FakeTransport();
    final player = await _player(fake, targetWins: 1);
    final result = player.run();

    fake.feed('You win the 1 point match 1-0');
    await pumpEventQueue();

    final r = await result;
    expect(r.wins, 1);
    expect(r.why, contains('target'));
  });

  test('counts a loss and keeps going (does not complete early)', () async {
    final fake = FakeTransport();
    final player = await _player(fake, targetWins: 2);
    unawaited(player.run());

    fake.feed('BlunderBot wins the 1 point match 1-0');
    await pumpEventQueue();

    expect(player.losses, 1);
    expect(player.wins, 0);
    player.stop('test');
  });
}
