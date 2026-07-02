import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart'; // re-exports WhoInfo
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

WhoInfo _bot(String user, {String client = 'ParlorBot'}) => WhoInfo(
  user: user,
  opponent: '',
  watching: '',
  ready: true,
  away: false,
  rating: 1500,
  experience: 1000,
  lastActive: DateTime(2020),
  lastLogin: DateTime(2020),
  hostname: '',
  client: client,
  email: '',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('invite dialog sends the chosen match length', (tester) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fibs.lobby.upsert(_bot('BlunderBot_II'));

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    final invite = find.byKey(const ValueKey('invite-BlunderBot_II'));
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pumpAndSettle();

    // default is a 3-point match; switch to 5 and invite
    expect(find.text('Invite (3 pt)'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite (5 pt)'));
    await tester.pumpAndSettle();

    expect(fake.sent, contains('invite BlunderBot_II 5'));
  });

  testWidgets('a 1-point-only bot defaults the match length to 1', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fibs.lobby.upsert(_bot('wildbg', client: 'bot_1p_matches_only'));

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    final invite = find.byKey(const ValueKey('invite-wildbg'));
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pumpAndSettle();

    expect(find.text('Invite (1 pt)'), findsOneWidget);
    expect(find.textContaining('only accepts 1-point'), findsOneWidget);
  });
}
