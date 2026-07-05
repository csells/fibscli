import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

WhoInfo _who(
  String user, {
  String opponent = '',
  bool ready = true,
  String client = 'ParlorBot',
}) => WhoInfo(
  user: user,
  opponent: opponent,
  watching: '',
  ready: ready,
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

  testWidgets('the lobby resumes a ready saved match on tap', (tester) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    // a `show savedgames` listing arrives on login
    fake.feed('**MG 0 0 - 1');
    fibs.lobby.upsert(_who('MG'));
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    // the unfinished match with MG is offered for resume (the section header
    // reads in editorial small-caps)
    expect(find.text('MG'), findsWidgets);
    expect(find.textContaining('Ready now'), findsOneWidget);
    expect(find.textContaining('tap Resume'), findsOneWidget);
    expect(find.textContaining('RESUME'), findsWidgets);

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    // resuming re-invites the opponent so FIBS reloads the saved match
    expect(fake.sent, contains('invite MG'));
    expect(find.textContaining('Resuming'), findsOneWidget);
    expect(find.text("Waiting for FIBS to load MG's board"), findsOneWidget);
    expect(find.textContaining('WAITING'), findsWidgets);
  });

  testWidgets('the lobby waits for live status before resuming a saved match', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('**MG 0 0 - 1');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MG'), findsOneWidget);
    expect(find.textContaining('Checking availability'), findsOneWidget);
    expect(
      find.text('Waiting for FIBS to confirm MG is ready'),
      findsOneWidget,
    );
    expect(find.textContaining('tap Resume'), findsNothing);

    await tester.ensureVisible(find.text('MG'));
    await tester.tap(find.text('MG'));
    await tester.pumpAndSettle();

    expect(fake.sent, isNot(contains('invite MG')));
  });

  testWidgets('the lobby explains a delayed resume attempt', (tester) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('**MG 0 0 - 1');
    fake.feed('12 MG I will not attempt to resume for 5 minutes.');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MG'), findsWidgets);
    expect(find.textContaining('Resume delayed'), findsOneWidget);
    expect(
      find.text('MG will not attempt to resume for 5 minutes.'),
      findsOneWidget,
    );
    expect(find.textContaining('tap Resume'), findsNothing);

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fake.sent, isNot(contains('invite MG')));
  });

  testWidgets('the lobby explains saved matches that cannot resume yet', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('  MG 0 0 - 1');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MG'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.text('MG is offline'), findsOneWidget);
    expect(find.textContaining('tap Resume'), findsNothing);

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fake.sent, isNot(contains('invite MG')));
  });

  testWidgets(
    'the lobby explains a saved-match opponent busy in another game',
    (tester) async {
      final fake = FakeTransport();
      final fibs = FibsState.withTransport(fake);
      await fibs.login(user: 'me', pass: 'pw');
      fake.feed('**MG 0 0 - 1');
      fibs.lobby.upsert(_who('MG', opponent: 'other_player'));
      await tester.pumpWidget(
        MaterialApp(
          home: FibsPage(fibs: fibs, creds: await fakeCreds()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MG'), findsWidgets);
      expect(find.textContaining('Busy right now'), findsOneWidget);
      expect(find.text('MG is playing other_player'), findsOneWidget);
      expect(find.textContaining('tap Resume'), findsNothing);

      final savedMatchName = find.text('MG').first;
      await tester.ensureVisible(savedMatchName);
      await tester.tap(savedMatchName);
      await tester.pumpAndSettle();

      expect(fake.sent, isNot(contains('invite MG')));
    },
  );

  testWidgets('the lobby resumes a saved-match opponent playing us', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('**MG 0 0 - 1');
    fibs.lobby.upsert(_who('MG', opponent: 'me'));
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MG'), findsWidgets);
    expect(find.textContaining('Active with you'), findsOneWidget);
    expect(find.text('MG is playing you'), findsOneWidget);
    expect(find.textContaining('RESUME'), findsWidgets);

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fake.sent, contains('board'));
    expect(fake.sent, isNot(contains('join MG')));
    expect(fake.sent, isNot(contains('invite MG')));
    expect(find.textContaining('Resuming'), findsOneWidget);
    expect(find.text("Waiting for FIBS to load MG's board"), findsOneWidget);
    expect(find.textContaining('WAITING'), findsWidgets);
  });

  testWidgets('the lobby clears loading state when resume is refused', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('**MG 0 0 - 1');
    fibs.lobby.upsert(_who('MG', opponent: 'me'));
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(find.textContaining('Resuming'), findsOneWidget);

    fake.feed('** MG is already playing with me.');
    await tester.pumpAndSettle();

    expect(find.textContaining('Resuming'), findsNothing);
    expect(find.text("Waiting for FIBS to load MG's board"), findsNothing);
    expect(find.textContaining('RESUME'), findsWidgets);
  });

  testWidgets('a login-time resume acknowledgement does not show as resuming', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    fake.feed('**MG 0 0 - 1');
    fibs.lobby.upsert(_who('MG', opponent: 'me'));
    fake.feed('You are now playing with MG. Your running match was loaded');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MG'), findsWidgets);
    expect(find.textContaining('Active with you'), findsOneWidget);
    expect(find.text('MG is playing you'), findsOneWidget);
    expect(find.textContaining('Resuming'), findsNothing);
    expect(find.text("Waiting for FIBS to load MG's board"), findsNothing);
    expect(fake.sent, isNot(contains('board')));
    expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));
  });

  testWidgets('an opponent resume request shows a ready saved-match row', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    fake.feed('MG wants to resume a saved match with you.');
    await tester.pumpAndSettle();

    expect(fake.sent, isNot(contains('join')));
    expect(find.text('MG'), findsOneWidget);
    expect(find.textContaining('Ready now'), findsOneWidget);

    final resumeAction = find.byKey(const ValueKey('resume-MG'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fake.sent, contains('join MG'));
    expect(fake.sent, isNot(contains('invite MG')));
    expect(find.textContaining('Resuming'), findsOneWidget);
    expect(find.text("Waiting for FIBS to load MG's board"), findsOneWidget);
    expect(find.textContaining('WAITING'), findsWidgets);
  });
}
