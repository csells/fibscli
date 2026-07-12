import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/ai_engines.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnubg_service/gnubg_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

GnubgSession _fakeSession() => GnubgSession(
  baseUrl: 'http://svc.test',
  publishableKey: 'bg_pk_example_public',
  attest: () async => 'fake-turnstile-response',
  httpClient: MockClient(
    (request) async => http.Response('{"error":"unused"}', 500),
  ),
);

Future<void> _pumpLanding(
  WidgetTester tester, {
  required bool garyAvailable,
}) async {
  SharedPreferences.setMockInitialValues({});
  App.prefs = await SharedPreferences.getInstance();
  AiRegistry.clear();
  AiRegistry.register(
    ComputerOpponentsFactory(sessionFor: garyAvailable ? _fakeSession : null),
  );
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LandingPage()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the computer section offers the 0-7 ladder', (tester) async {
    await _pumpLanding(tester, garyAvailable: true);

    expect(find.text('Play Against the Computer'), findsOneWidget);
    for (var n = 0; n <= 7; n++) {
      expect(find.text('$n'), findsWidgets, reason: 'level chip $n');
    }
  });

  testWidgets('selecting a level shows its persona label', (tester) async {
    await _pumpLanding(tester, garyAvailable: true);

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(
      find.textContaining('Level 0 — Harry Heuristic — ELO 1450 · offline'),
      findsOneWidget,
    );

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(
      find.textContaining('Level 7 — Gary Gammon — world-class'),
      findsOneWidget,
    );
  });

  testWidgets('without a key the Gary levels are visible but inert', (
    tester,
  ) async {
    await _pumpLanding(tester, garyAvailable: false);

    // The full ladder still shows...
    for (var n = 0; n <= 7; n++) {
      expect(find.text('$n'), findsWidgets, reason: 'level chip $n');
    }
    // ...an unavailability note names the online opponent...
    expect(find.textContaining('web only'), findsOneWidget);
    // ...and tapping a Gary chip does not select it: the caption keeps
    // naming Harry (level 0, the only playable step).
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.textContaining('Level 0 — Harry Heuristic'), findsOneWidget);
    expect(find.textContaining('Level 5'), findsNothing);
  });
}
