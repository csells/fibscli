import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

WhoInfo who(
  String user, {
  String opponent = '',
  bool ready = true,
  String client = '3DFiBs4.0', // a human GUI client by default
}) => WhoInfo(
  user: user,
  opponent: opponent,
  watching: '',
  ready: ready,
  away: false,
  rating: 1500,
  experience: 0,
  lastActive: DateTime(2020),
  lastLogin: DateTime(2020),
  hostname: 'h',
  client: client,
  email: '',
);

void main() {
  group('FibsState bots-only (milestone 1)', () {
    test('isBot keys on the client string, not the name', () {
      // bot clients seen live on FIBS
      expect(FibsState.isBot(who('BlunderBot', client: 'ParlorBot')), isTrue);
      expect(
        FibsState.isBot(who('pubeval', client: 'Computer_player')),
        isTrue,
      );
      expect(
        FibsState.isBot(who('wildbg', client: 'bot_1p_matches_only')),
        isTrue,
      );
      // a human GUI client is not a bot, even with a botty-looking name
      expect(FibsState.isBot(who('Robotnik', client: '3DFiBs4.0')), isFalse);
      // a "Bot"-named tournament organizer is NOT a playable bot client
      expect(
        FibsState.isBot(who('TourneyBot', client: '=NTTourney1rganizer2')),
        isFalse,
      );
      // MonteCarlo reports no client but is a confirmed bot on the curated
      // known-names list
      expect(FibsState.isBot(who('MonteCarlo', client: '-')), isTrue);
      // an unknown account that reports no client is still excluded
      expect(FibsState.isBot(who('randomdude', client: '-')), isFalse);
    });

    test(
      'availableBots = free bot-client accounts (no humans, no busy bots)',
      () {
        final state = FibsState();
        state.whoInfos.addAll([
          who('BlunderBot', client: 'ParlorBot'), //                  free bot ✓
          who('GammonBot', client: 'ParlorBot', opponent: 'joe'), //  busy bot ✗
          who(
            'SleepyBot',
            client: 'ParlorBot',
            ready: false,
          ), //     not ready ✗
          who('alice', client: 'MGOnline_v1.4.2'), //                 human ✗
        ]);

        expect(state.availableBots.map((w) => w.user), ['BlunderBot']);
      },
    );

    test('watchableBots = bot-client accounts currently in a game', () {
      final state = FibsState();
      state.whoInfos.addAll([
        who('BlunderBot', client: 'ParlorBot', opponent: 'human1'), // ✓
        who('IdleBot', client: 'ParlorBot'), //                  not playing ✗
        who('bob', client: '3DFiBs4.0', opponent: 'alice'), //   humans ✗
      ]);

      expect(state.watchableBots.map((w) => w.user), ['BlunderBot']);
    });

    test('who-info cookies notify FibsState listeners', () async {
      final fake = FakeTransport();
      final state = FibsState.withTransport(fake);
      await state.login(user: 'joe', pass: 'pw');
      var notifications = 0;
      state.addListener(() => notifications += 1);

      fake.feed(
        '5 BlunderBot - - 1 0 1500.00 42 0 1041253132 host ParlorBot -',
      );
      await Future<void>.delayed(Duration.zero);

      expect(state.availableBots.map((w) => w.user), ['BlunderBot']);
      expect(notifications, greaterThan(0));
    });
  });
}
