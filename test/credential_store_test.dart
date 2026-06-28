import 'package:fibscli/credential_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';

Future<SecureCredentialStore> _loaded(
  FakeSecretStore secret,
  SharedPreferences prefs,
) async {
  final store = SecureCredentialStore(prefs, secret);
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecretStore secret;
  late SharedPreferences prefs;

  setUp(() async {
    secret = FakeSecretStore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'remembering stores the password in secure storage, never in prefs',
    () async {
      final store = await _loaded(secret, prefs);
      await store.save(user: 'joe', password: 'hunter2', remember: true);

      // password is in the secret store...
      expect(secret.values.values, contains('hunter2'));
      // ...and NOT anywhere in SharedPreferences (at-rest privacy)
      final inPrefs = prefs.getKeys().any(
        (k) => '${prefs.get(k)}'.contains('hunter2'),
      );
      expect(inPrefs, isFalse);

      // a fresh store loads them back
      final reloaded = await _loaded(secret, prefs);
      expect(reloaded.user, 'joe');
      expect(reloaded.password, 'hunter2');
      expect(reloaded.remember, isTrue);
      expect(reloaded.canAutologin, isTrue);
    },
  );

  test('not remembering keeps the username but no password', () async {
    final store = await _loaded(secret, prefs);
    await store.save(user: 'joe', password: 'hunter2', remember: false);
    expect(secret.values, isEmpty);

    final reloaded = await _loaded(secret, prefs);
    expect(reloaded.user, 'joe'); // username is convenience, not a secret
    expect(reloaded.password, isNull);
    expect(reloaded.canAutologin, isFalse);
  });

  test('forget drops the password but keeps the username', () async {
    final store = await _loaded(secret, prefs);
    await store.save(user: 'joe', password: 'hunter2', remember: true);

    await store.forget();

    expect(secret.values, isEmpty);
    expect(store.password, isNull);
    expect(store.remember, isFalse);
    expect(store.user, 'joe');
    expect(store.canAutologin, isFalse);
  });
}
