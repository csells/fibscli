import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

WhoInfo who(String user, {String opponent = '', bool ready = true}) => WhoInfo(
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
      client: 'c',
      email: '',
    );

void main() {
  group('FibsState bots-only (milestone 1)', () {
    test('isBot uses the name heuristic', () {
      expect(FibsState.isBot('BlunderBot'), isTrue);
      expect(FibsState.isBot('GammonBot_iv'), isTrue);
      expect(FibsState.isBot('chris'), isFalse);
    });

    test('availableBots = free bots only (no humans, no busy bots)', () {
      final state = FibsState();
      state.whoInfos.addAll([
        who('BlunderBot'), //              free bot -> included
        who('GammonBot', opponent: 'joe'), // busy bot -> excluded
        who('NotReadyBot', ready: false), // not ready -> excluded
        who('alice'), //                   human -> excluded
      ]);

      expect(state.availableBots.map((w) => w.user), ['BlunderBot']);
    });

    test('watchableBots = bots currently in a game', () {
      final state = FibsState();
      state.whoInfos.addAll([
        who('BlunderBot', opponent: 'GammonBot'), // playing -> watchable
        who('IdleBot'), //                          free -> not watchable
        who('bob', opponent: 'alice'), //           humans playing -> excluded
      ]);

      expect(state.watchableBots.map((w) => w.user), ['BlunderBot']);
    });
  });
}
