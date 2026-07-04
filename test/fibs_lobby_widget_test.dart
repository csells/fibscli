import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

WhoInfo _bot(
  String user, {
  String client = 'ParlorBot',
  String opponent = '',
  double rating = 1500,
  int experience = 1000,
}) => WhoInfo(
  user: user,
  opponent: opponent,
  watching: '',
  ready: true,
  away: false,
  rating: rating,
  experience: experience,
  lastActive: DateTime(2020),
  lastLogin: DateTime(2020),
  hostname: '',
  client: client,
  email: '',
);

Future<(FibsState, FakeTransport)> _pumpLobby(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final fake = FakeTransport();
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'me', pass: 'pw');
  fibs.lobby
    ..upsert(_bot('me', client: '3DFiBs4.0', rating: 1625, experience: 240))
    ..upsert(_bot('BlunderBot_II', rating: 1528))
    ..upsert(_bot('MonteCarlo', client: '', opponent: 'human1', rating: 2040));

  await tester.pumpWidget(
    MaterialApp(
      home: FibsPage(fibs: fibs, creds: await fakeCreds()),
    ),
  );
  await tester.pumpAndSettle();
  return (fibs, fake);
}

double _rowTop(WidgetTester tester, String bot) =>
    tester.getTopLeft(find.text(bot)).dy;

void main() {
  testWidgets('FIBS lobby renders the editorial directory layout', (
    tester,
  ) async {
    await _pumpLobby(tester);

    expect(
      find.text('The Directory · Live from fibs.com:4321'),
      findsOneWidget,
    );
    expect(find.text("Who's on\nthe server"), findsOneWidget);
    expect(find.text('Bots online'), findsOneWidget);
    expect(find.text('BOT'), findsOneWidget);
    expect(find.text('STRENGTH'), findsOneWidget);
    expect(find.text('RATING'), findsOneWidget);
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('BlunderBot_II'), findsOneWidget);
    expect(find.text('MonteCarlo'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-BlunderBot_II')), findsOneWidget);
    expect(find.byKey(const ValueKey('watch-MonteCarlo')), findsOneWidget);
    expect(find.byKey(const ValueKey('watch-BlunderBot_II')), findsNothing);
    expect(find.byKey(const ValueKey('invite-MonteCarlo')), findsNothing);
    expect(find.text('FIBS rating 1625 · 240 exp'), findsOneWidget);
    expect(find.textContaining('visible'), findsNothing);
    expect(find.textContaining('ready bots'), findsNothing);
  });

  testWidgets('FIBS lobby actions preserve invite and watch behavior', (
    tester,
  ) async {
    final (_, fake) = await _pumpLobby(tester);

    final watch = find.byKey(const ValueKey('watch-MonteCarlo'));
    await tester.ensureVisible(watch);
    await tester.tap(watch);
    await tester.pumpAndSettle();

    expect(fake.sent, contains('watch MonteCarlo'));
  });

  testWidgets('FIBS lobby headings sort the directory rows', (tester) async {
    await _pumpLobby(tester);

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(
      _rowTop(tester, 'BlunderBot_II'),
      lessThan(_rowTop(tester, 'MonteCarlo')),
    );

    await tester.tap(find.text('RATING'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(
      _rowTop(tester, 'MonteCarlo'),
      lessThan(_rowTop(tester, 'BlunderBot_II')),
    );

    await tester.tap(find.text('RATING'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(
      _rowTop(tester, 'BlunderBot_II'),
      lessThan(_rowTop(tester, 'MonteCarlo')),
    );

    await tester.tap(find.text('STRENGTH'));
    await tester.pumpAndSettle();
    expect(
      _rowTop(tester, 'BlunderBot_II'),
      lessThan(_rowTop(tester, 'MonteCarlo')),
    );

    await tester.tap(find.text('STRENGTH'));
    await tester.pumpAndSettle();
    expect(
      _rowTop(tester, 'MonteCarlo'),
      lessThan(_rowTop(tester, 'BlunderBot_II')),
    );

    await tester.tap(find.text('TABLE'));
    await tester.pumpAndSettle();
    expect(
      _rowTop(tester, 'BlunderBot_II'),
      lessThan(_rowTop(tester, 'MonteCarlo')),
    );

    await tester.tap(find.text('TABLE'));
    await tester.pumpAndSettle();
    expect(
      _rowTop(tester, 'MonteCarlo'),
      lessThan(_rowTop(tester, 'BlunderBot_II')),
    );
  });
}
