import 'package:fibscli/error_log_dialog.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/logging.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appErrors.value = null;
    errorHistory.clear();
  });

  // An uncaught error reported from anywhere (here, the global handlers'
  // reportError) is shown to the USER as a SnackBar carrying the context + a
  // Details action -- not silently dropped into the dev console.
  testWidgets('a reported error is surfaced to the user as a SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(App(fibs: FibsState(), creds: await fakeCreds()));
    await tester.pump(); // first frame

    expect(find.byType(SnackBar), findsNothing);

    // simulate an uncaught error (what FlutterError.onError / the zone handler do)
    reportError(
      StateError('connection lost'),
      StackTrace.current,
      context: 'login',
    );
    await tester.pump(); // let the listener fire + the SnackBar animate in

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('login'), findsOneWidget); // what went wrong
    expect(
      find.widgetWithText(SnackBarAction, 'Details'),
      findsOneWidget,
    ); // action
  });

  // The SnackBar is transient; "Details" opens the retained error log so the
  // user can read the full detail and copy recent errors into a bug report.
  testWidgets('tapping Details opens the retained error log', (tester) async {
    await tester.pumpWidget(App(fibs: FibsState(), creds: await fakeCreds()));
    await tester.pump();

    reportError(StateError('boom detail'), StackTrace.current, context: 'fibs');
    await tester.pump(); // listener fires, SnackBar starts animating in
    await tester.pump(const Duration(seconds: 1)); // fully on-screen

    await tester.tap(find.widgetWithText(SnackBarAction, 'Details'));
    await tester.pump(); // start the dialog route
    await tester.pump(const Duration(milliseconds: 300)); // animate it in

    expect(find.byType(ErrorLogDialog), findsOneWidget);
    // the retained error's detail is shown
    expect(find.textContaining('boom detail'), findsWidgets);
  });
}
