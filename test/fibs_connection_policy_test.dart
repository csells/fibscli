import 'package:fibscli/fibs_connection_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'login clears expected-close mode and successful login rearms reconnect',
    () {
      const policy = FibsConnectionPolicy(
        expectClose: true,
        reconnectUsed: true,
        autoLoginTried: true,
      );

      final loggingIn = policy.beginLogin();
      final loggedIn = loggingIn.loginSucceeded();

      expect(loggingIn.expectClose, isFalse);
      expect(loggingIn.reconnectUsed, isTrue);
      expect(loggedIn.reconnectUsed, isFalse);
      expect(loggedIn.autoLoginTried, isTrue);
    },
  );

  test('explicit logout spends autologin and treats the close as silent', () {
    const policy = FibsConnectionPolicy();

    final loggingOut = policy.beginExpectedClose(spendAutoLogin: true);
    final close = loggingOut.handleConnectionClosed(canReconnect: true);

    expect(loggingOut.autoLoginTried, isTrue);
    expect(close.action, FibsConnectionCloseAction.ignore);
    expect(close.state.autoLoginTried, isTrue);
    expect(close.state.reconnectUsed, isFalse);
  });

  test(
    'unexpected close spends one reconnect, then falls back to login notice',
    () {
      const policy = FibsConnectionPolicy();

      final first = policy.handleConnectionClosed(canReconnect: true);
      final second = first.state.handleConnectionClosed(canReconnect: true);
      final withoutHook = policy.handleConnectionClosed(canReconnect: false);

      expect(first.action, FibsConnectionCloseAction.reconnect);
      expect(first.state.reconnectUsed, isTrue);
      expect(second.action, FibsConnectionCloseAction.showLoginNotice);
      expect(withoutHook.action, FibsConnectionCloseAction.showLoginNotice);
    },
  );

  test('temporary expected-close scopes can be finished', () {
    final policy = const FibsConnectionPolicy()
        .beginExpectedClose()
        .finishExpectedCloseScope();

    expect(policy.expectClose, isFalse);
    expect(policy.autoLoginTried, isFalse);
  });
}
