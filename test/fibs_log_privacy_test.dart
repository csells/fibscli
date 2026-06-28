import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'fake_transport.dart';

void main() {
  // Cookie tracing must never log other users' PII. The FIBS who-list carries
  // email addresses and chat carries message text; logging full cookie content
  // would leak both into the dev console / any log sink.
  test('cookie logging never leaks PII (emails, chat)', () async {
    final records = <LogRecord>[];
    final prevLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      await sub.cancel();
      Logger.root.level = prevLevel;
    });

    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');

    // a who-info line carrying another user's email, and a shout (chat)
    fake.feed('5 spy - - 1 0 1500.00 1 0 1 host ParlorBot spy@example.com');
    fake.feed('13 gossip secret message here');
    await pumpEventQueue();

    final logged = records.map((r) => '${r.message} ${r.error}').join('\n');
    expect(logged, isNot(contains('@example.com')));
    expect(logged, isNot(contains('secret message')));
  });
}
