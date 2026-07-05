import 'package:fibscli/fibs_connection_lifecycle.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

class _StickyCloseTransport extends FakeTransport {
  @override
  Future<void> close() async {}
}

class _SecondCommandThrowingTransport extends FakeTransport {
  @override
  void sendBatch(Iterable<String> commands) {
    final pending = commands.toList(growable: false);
    if (pending.contains('show savedgames')) {
      throw StateError('socket write failed');
    }
    super.sendBatch(pending);
  }
}

void main() {
  test('login cleanup allows a fresh production-like transport', () async {
    final transports = [
      StrictFakeTransport(FibsCookie.FIBS_FailedLogin),
      StrictFakeTransport(FibsCookie.CLIP_WELCOME),
    ];
    final lifecycle = FibsConnectionLifecycle(
      makeTransport: () => transports.removeAt(0),
      loginTimeout: const Duration(milliseconds: 50),
    );

    final rejected = await lifecycle.login(
      user: 'me',
      pass: 'wrong',
      onCookie: (_) {},
      onError: (_, _) {},
      onDone: () {},
    );
    expect(rejected, FibsCookie.FIBS_FailedLogin);
    await lifecycle.closeCurrent();
    expect(lifecycle.connected, isFalse);

    final accepted = await lifecycle.login(
      user: 'me',
      pass: 'right',
      onCookie: (_) {},
      onError: (_, _) {},
      onDone: () {},
    );
    expect(accepted, FibsCookie.CLIP_WELCOME);
    expect(lifecycle.connected, isTrue);
  });

  test(
    'close detaches lifecycle state before waiting for transport close',
    () async {
      final fake = _StickyCloseTransport();
      final lifecycle = FibsConnectionLifecycle(
        makeTransport: () => fake,
        loginTimeout: const Duration(milliseconds: 50),
      );

      await lifecycle.login(
        user: 'me',
        pass: 'pw',
        onCookie: (_) {},
        onError: (_, _) {},
        onDone: () {},
      );
      expect(fake.connected, isTrue);

      await lifecycle.closeCurrent();

      expect(fake.connected, isTrue);
      expect(lifecycle.connected, isFalse);
    },
  );

  test(
    'command batches are sent as an all-or-nothing transport effect',
    () async {
      final fake = _SecondCommandThrowingTransport();
      final lifecycle = FibsConnectionLifecycle(
        makeTransport: () => fake,
        loginTimeout: const Duration(milliseconds: 50),
      );

      await lifecycle.login(
        user: 'me',
        pass: 'pw',
        onCookie: (_) {},
        onError: (_, _) {},
        onDone: () {},
      );

      expect(
        () => lifecycle.sendAll(const ['leave', 'show savedgames']),
        throwsStateError,
      );
      expect(fake.sent, isEmpty);
    },
  );
}
