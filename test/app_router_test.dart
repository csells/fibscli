import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

class _RouteTestAi extends BgAiPlayer {
  @override
  String get name => 'Route Test AI';

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async => const BgTurn([]);
}

class _RouteTestAiFactory extends BgAiPlayerFactory {
  @override
  String get name => 'Computer';

  @override
  List<String> get levels => const ['0', '1', '2', '3', '4', '5', '6', '7'];

  @override
  BgAiPlayer create({String? level}) => _RouteTestAi();
}

String _boardLine({
  String player1 = 'me',
  String player2 = 'wildbg',
  String turn = '1',
  String p1dice = '6:3',
}) => [
  'board:$player1:$player2:1:0:0:0',
  '-2:0:0:0:0:5:0:3:0:0:0:-5:5',
  '0:0:0:-3:0:-5:0:0:0:0:2:0',
  '$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0',
].join(':');

WhoInfo _who(String user, {String opponent = '', bool ready = true}) => WhoInfo(
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
  client: 'ParlorBot',
  email: '',
);

void main() {
  Future<FibsState> pumpAt(
    WidgetTester tester,
    String location, {
    Future<void> Function(FibsState fibs, FakeTransport fake)? configure,
  }) async {
    SharedPreferences.setMockInitialValues({});
    App.prefs = await SharedPreferences.getInstance();
    AiRegistry.register(_RouteTestAiFactory());
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await configure?.call(fibs, fake);
    await tester.pumpWidget(
      App(fibs: fibs, creds: await fakeCreds(), initialLocation: location),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return fibs;
  }

  String routePath(WidgetTester tester) {
    final element = tester.element(find.byType(FibsPage));
    return GoRouterState.of(element).uri.path;
  }

  test('computer route locations encode query parameters', () {
    expect(
      AppRoutes.computerLocation(engine: 'Computer', level: '3'),
      '/computer?engine=Computer&level=3',
    );
  });

  testWidgets('home route is deep-linkable', (tester) async {
    await pumpAt(tester, AppRoutes.home);

    expect(find.byType(LandingPage), findsOneWidget);
  });

  testWidgets('home route leads with FIBS, then computer, then local', (
    tester,
  ) async {
    await pumpAt(tester, AppRoutes.home);

    final fibsTop = tester.getTopLeft(find.text('Play a Bot on FIBS')).dy;
    final computerTop = tester
        .getTopLeft(find.text('Play Against the Computer'))
        .dy;
    final localTop = tester.getTopLeft(find.text('Local 2-Player')).dy;

    expect(fibsTop, lessThan(computerTop));
    expect(computerTop, lessThan(localTop));
  });

  testWidgets('home route links to repo feedback and about', (tester) async {
    SharedPreferences.setMockInitialValues({});
    App.prefs = await SharedPreferences.getInstance();
    final launched = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          openUrl: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('FEEDBACK'));
    await tester.pump();
    await tester.tap(find.text('ABOUT'));
    await tester.pump();

    expect(launched.map((uri) => uri.toString()), [
      playFibsIssuesUrl,
      playFibsRepoUrl,
    ]);
  });

  testWidgets('home route discloses sanitized analytics', (tester) async {
    await pumpAt(tester, AppRoutes.home);

    expect(
      find.textContaining('Analytics are aggregate app events only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('We never send passwords', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('privacy route is deep-linkable', (tester) async {
    await pumpAt(tester, AppRoutes.privacy);

    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(find.text('FIBS connection'), findsOneWidget);
  });

  testWidgets('local game route is deep-linkable', (tester) async {
    await pumpAt(tester, AppRoutes.local);

    expect(find.byType(GamePlayPage), findsOneWidget);
  });

  testWidgets('computer game route is deep-linkable', (tester) async {
    await pumpAt(
      tester,
      AppRoutes.computerLocation(engine: 'Computer', level: '3'),
    );

    expect(find.byType(GamePlayPage), findsOneWidget);
  });

  testWidgets('FIBS route is deep-linkable', (tester) async {
    await pumpAt(tester, AppRoutes.fibs);

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsLogin);
  });

  testWidgets('FIBS login route is deep-linkable', (tester) async {
    await pumpAt(tester, AppRoutes.fibsLogin);

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsLogin);
  });

  testWidgets('FIBS login route redirects to lobby after async login', (
    tester,
  ) async {
    final fibs = await pumpAt(tester, AppRoutes.fibsLogin);

    expect(routePath(tester), AppRoutes.fibsLogin);

    await fibs.login(user: 'me', pass: 'pw');
    await tester.pumpAndSettle();

    expect(routePath(tester), AppRoutes.fibsBots);
  });

  testWidgets('FIBS bots route redirects to login when logged out', (
    tester,
  ) async {
    await pumpAt(tester, AppRoutes.fibsBots);

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsLogin);
  });

  testWidgets('FIBS bots route is deep-linkable when logged in', (
    tester,
  ) async {
    await pumpAt(
      tester,
      AppRoutes.fibsBots,
      configure: (fibs, fake) => fibs.login(user: 'me', pass: 'pw'),
    );

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsBots);
    expect(find.text('Bots online'), findsOneWidget);
  });

  testWidgets('FIBS resume action enters play when the saved board arrives', (
    tester,
  ) async {
    late FakeTransport fakeTransport;
    await pumpAt(
      tester,
      AppRoutes.fibsBots,
      configure: (fibs, fake) async {
        fakeTransport = fake;
        await fibs.login(user: 'me', pass: 'pw');
        fake.feed('**wildbg 0 0 - 1');
        fibs.lobby.upsert(_who('wildbg'));
      },
    );

    expect(routePath(tester), AppRoutes.fibsBots);
    final resumeAction = find.byKey(const ValueKey('resume-wildbg'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fakeTransport.sent, contains('invite wildbg'));
    expect(find.textContaining('Resuming'), findsOneWidget);

    fakeTransport.feed(_boardLine());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(routePath(tester), AppRoutes.fibsPlay);
  });

  testWidgets('FIBS resume acknowledgement requests a board before play', (
    tester,
  ) async {
    late FakeTransport fakeTransport;
    await pumpAt(
      tester,
      AppRoutes.fibsBots,
      configure: (fibs, fake) async {
        fakeTransport = fake;
        await fibs.login(user: 'me', pass: 'pw');
        fake.feed('**wildbg 0 0 - 1');
        fibs.lobby.upsert(_who('wildbg'));
      },
    );

    final resumeAction = find.byKey(const ValueKey('resume-wildbg'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    fakeTransport.feed('wildbg has joined you. Your running match was loaded');
    await tester.pumpAndSettle();

    expect(fakeTransport.sent, contains('invite wildbg'));
    expect(fakeTransport.sent, contains('board'));
    expect(routePath(tester), AppRoutes.fibsBots);
    expect(find.textContaining('Resuming'), findsOneWidget);
    expect(
      find.text("Waiting for FIBS to load wildbg's board"),
      findsOneWidget,
    );

    fakeTransport.feed(_boardLine());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(routePath(tester), AppRoutes.fibsPlay);
  });

  testWidgets('FIBS active saved match resumes by requesting the board', (
    tester,
  ) async {
    late FakeTransport fakeTransport;
    await pumpAt(
      tester,
      AppRoutes.fibsBots,
      configure: (fibs, fake) async {
        fakeTransport = fake;
        await fibs.login(user: 'me', pass: 'pw');
        fake.feed('**wildbg 0 0 - 1');
        fibs.lobby.upsert(_who('wildbg', opponent: 'me'));
      },
    );

    final resumeAction = find.byKey(const ValueKey('resume-wildbg'));
    await tester.ensureVisible(resumeAction);
    await tester.tap(resumeAction);
    await tester.pumpAndSettle();

    expect(fakeTransport.sent, contains('board'));
    expect(fakeTransport.sent, isNot(contains('join wildbg')));
    expect(fakeTransport.sent, isNot(contains('invite wildbg')));
    expect(find.textContaining('Resuming'), findsOneWidget);

    fakeTransport.feed(_boardLine());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(routePath(tester), AppRoutes.fibsPlay);
  });

  testWidgets('FIBS play route is deep-linkable during a game', (tester) async {
    await pumpAt(
      tester,
      AppRoutes.fibsPlay,
      configure: (fibs, fake) async {
        await fibs.login(user: 'me', pass: 'pw');
        fibs.resumeSavedMatch('wildbg');
        fake.feed(_boardLine());
      },
    );

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsPlay);
  });

  testWidgets('FIBS watch route is deep-linkable while spectating', (
    tester,
  ) async {
    await pumpAt(
      tester,
      AppRoutes.fibsWatch,
      configure: (fibs, fake) async {
        await fibs.login(user: 'me', pass: 'pw');
        fibs.resumeSavedMatch('wildbg');
        fake.feed(_boardLine(player1: 'alice', player2: 'wildbg'));
      },
    );

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsWatch);
  });

  testWidgets('stale FIBS play route redirects to bots while logged in', (
    tester,
  ) async {
    await pumpAt(
      tester,
      AppRoutes.fibsPlay,
      configure: (fibs, fake) => fibs.login(user: 'me', pass: 'pw'),
    );

    expect(find.byType(FibsPage), findsOneWidget);
    expect(routePath(tester), AppRoutes.fibsBots);
  });
}
