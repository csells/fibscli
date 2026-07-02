import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/main.dart';
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
  String get name => 'Gary Gammon';

  @override
  List<String> get levels => const ['1', '2', '3', '4', '5'];

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
      AppRoutes.computerLocation(engine: 'Gary Gammon', level: '3'),
      '/computer?engine=Gary+Gammon&level=3',
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
    final computerTop = tester.getTopLeft(find.text('Play Gary Gammon')).dy;
    final localTop = tester.getTopLeft(find.text('Local 2-Player')).dy;

    expect(fibsTop, lessThan(computerTop));
    expect(computerTop, lessThan(localTop));
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
      AppRoutes.computerLocation(engine: 'Gary Gammon', level: '3'),
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

  testWidgets('FIBS play route is deep-linkable during a game', (tester) async {
    await pumpAt(
      tester,
      AppRoutes.fibsPlay,
      configure: (fibs, fake) async {
        await fibs.login(user: 'me', pass: 'pw');
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
