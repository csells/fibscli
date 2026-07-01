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
  });

  // #1 (reframed): an uncaught error reported from anywhere (here, the global
  // handlers' reportError) is shown to the USER as a SnackBar carrying the
  // context + a Copy action -- not silently dropped into the dev console.
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
      find.widgetWithText(SnackBarAction, 'Copy'),
      findsOneWidget,
    ); // action
  });
}
