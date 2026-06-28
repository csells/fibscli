import 'package:fibscli/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The app loads SharedPreferences BEFORE building any UI, so App.prefs is
  // never null while widgets exist. That invariant is what lets the login view
  // read remembered credentials synchronously (no load-race retry dance).
  test('bootstrap loads SharedPreferences before the app runs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'user': 'joe_grammer'});
    App.prefs.value = null;

    await bootstrap();

    expect(App.prefs.value, isNotNull);
    expect(App.prefs.value!.getString('user'), 'joe_grammer');
  });
}
