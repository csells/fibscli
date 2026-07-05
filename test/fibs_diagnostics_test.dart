import 'package:fibscli/fibs_diagnostics.dart';
import 'package:fibscli/fibs_protocol.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

CookieMessage _cookie(FibsCookie cookie) =>
    CookieMessage(cookie, cookie.name, null, CookieMonsterState.FIBS_RUN_STATE);

void main() {
  test('records sanitized cookie counters', () {
    final diagnostics = const FibsDiagnostics()
        .recordCookie(_cookie(FibsCookie.CLIP_WHO_INFO))
        .recordCookie(_cookie(FibsCookie.CLIP_WHO_END));

    expect(diagnostics.cookieCount, 2);
    expect(diagnostics.lastCookie, FibsCookie.CLIP_WHO_END);
    expect(diagnostics.whoInfoCookieCount, 1);
    expect(diagnostics.whoListComplete, isTrue);
  });

  test('records latest protocol signals and cumulative signal count', () {
    final signaled = const FibsDiagnostics().recordTransition(
      const FibsProtocolTransition(
        state: FibsProtocolState(),
        signals: {FibsProtocolSignal.commandRejected},
      ),
    );
    final quiet = signaled.recordTransition(
      const FibsProtocolTransition(state: FibsProtocolState()),
    );

    expect(signaled.protocolSignalCount, 1);
    expect(
      signaled.lastProtocolSignals,
      contains(FibsProtocolSignal.commandRejected),
    );
    expect(signaled.lastCommandRejected, isTrue);
    expect(quiet.protocolSignalCount, 1);
    expect(quiet.lastProtocolSignals, isEmpty);
    expect(quiet.lastCommandRejected, isFalse);
  });

  test('records match results and resets', () {
    const result = FibsProtocolMatchResult(
      didIWin: true,
      message: 'You win the 1 point match 1-0.',
    );
    final diagnostics = const FibsDiagnostics().recordTransition(
      const FibsProtocolTransition(
        state: FibsProtocolState(),
        matchResult: result,
      ),
    );

    expect(diagnostics.protocolMatchResultCount, 1);
    expect(diagnostics.lastProtocolMatchResult, same(result));
    expect(diagnostics.reset(), const FibsDiagnostics());
  });
}
