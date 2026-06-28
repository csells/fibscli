import 'package:fibscli/fibs_lobby.dart';
import 'package:flutter_test/flutter_test.dart';

WhoInfo _who(
  String user, {
  String client = '-',
  String opponent = '',
  bool ready = true,
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
  hostname: '',
  client: client,
  email: '',
);

void main() {
  test('upsert replaces a same-named entry (names are unique on FIBS)', () {
    final lobby = FibsLobby()
      ..upsert(_who('BlunderBot', client: 'ParlorBot', ready: true))
      ..upsert(_who('BlunderBot', client: 'ParlorBot', ready: false));
    expect(lobby.entries.length, 1);
    expect(lobby.entries.first.ready, isFalse); // the update won
  });

  test('availableBots = ready bot-client accounts not already in a game', () {
    final lobby = FibsLobby()
      ..upsert(_who('BlunderBot', client: 'ParlorBot')) // free bot
      ..upsert(_who('alice', client: '3DFiBs')) // human
      ..upsert(_who('GammonBot', client: 'ParlorBot', opponent: 'bob')); // busy
    expect(lobby.availableBots.map((w) => w.user), ['BlunderBot']);
  });

  test('watchableBots = bot-client accounts currently in a game', () {
    final lobby = FibsLobby()
      ..upsert(_who('BlunderBot', client: 'ParlorBot', opponent: 'bob'))
      ..upsert(_who('idleBot', client: 'ParlorBot')); // not in a game
    expect(lobby.watchableBots.map((w) => w.user), ['BlunderBot']);
  });

  test('remove drops the named entry; clear empties the roster', () {
    final lobby = FibsLobby()
      ..upsert(_who('a'))
      ..upsert(_who('b'));
    lobby.remove('a');
    expect(lobby.entries.map((w) => w.user), ['b']);
    lobby.clear();
    expect(lobby.entries, isEmpty);
  });
}
