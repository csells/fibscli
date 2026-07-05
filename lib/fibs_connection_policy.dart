import 'package:flutter/foundation.dart';

enum FibsConnectionCloseAction { ignore, reconnect, showLoginNotice }

@immutable
class FibsConnectionCloseDecision {
  const FibsConnectionCloseDecision({
    required this.state,
    required this.action,
  });

  final FibsConnectionPolicy state;
  final FibsConnectionCloseAction action;
}

@immutable
class FibsConnectionPolicy {
  const FibsConnectionPolicy({
    this.expectClose = false,
    this.reconnectUsed = false,
    this.autoLoginTried = false,
  });

  final bool expectClose;
  final bool reconnectUsed;
  final bool autoLoginTried;

  FibsConnectionPolicy beginLogin() => copyWith(expectClose: false);

  FibsConnectionPolicy loginSucceeded() => copyWith(reconnectUsed: false);

  FibsConnectionPolicy markAutoLoginTried() => copyWith(autoLoginTried: true);

  FibsConnectionPolicy beginExpectedClose({bool spendAutoLogin = false}) =>
      copyWith(
        expectClose: true,
        autoLoginTried: autoLoginTried || spendAutoLogin,
      );

  FibsConnectionPolicy finishExpectedCloseScope() =>
      copyWith(expectClose: false);

  FibsConnectionCloseDecision handleConnectionClosed({
    required bool canReconnect,
  }) {
    if (expectClose) {
      return FibsConnectionCloseDecision(
        state: this,
        action: FibsConnectionCloseAction.ignore,
      );
    }
    if (canReconnect && !reconnectUsed) {
      return FibsConnectionCloseDecision(
        state: copyWith(reconnectUsed: true),
        action: FibsConnectionCloseAction.reconnect,
      );
    }
    return FibsConnectionCloseDecision(
      state: this,
      action: FibsConnectionCloseAction.showLoginNotice,
    );
  }

  FibsConnectionPolicy copyWith({
    bool? expectClose,
    bool? reconnectUsed,
    bool? autoLoginTried,
  }) => FibsConnectionPolicy(
    expectClose: expectClose ?? this.expectClose,
    reconnectUsed: reconnectUsed ?? this.reconnectUsed,
    autoLoginTried: autoLoginTried ?? this.autoLoginTried,
  );
}
