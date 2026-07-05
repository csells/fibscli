import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_protocol.dart';

@immutable
class FibsDiagnostics {
  const FibsDiagnostics({
    this.cookieCount = 0,
    this.lastCookie,
    this.protocolSignalCount = 0,
    this.lastProtocolSignals = const {},
    this.protocolMatchResultCount = 0,
    this.lastProtocolMatchResult,
    this.whoInfoCookieCount = 0,
    this.whoListComplete = false,
  });

  final int cookieCount;
  final FibsCookie? lastCookie;
  final int protocolSignalCount;
  final Set<FibsProtocolSignal> lastProtocolSignals;
  final int protocolMatchResultCount;
  final FibsProtocolMatchResult? lastProtocolMatchResult;
  final int whoInfoCookieCount;
  final bool whoListComplete;

  bool get lastCommandRejected =>
      lastProtocolSignals.contains(FibsProtocolSignal.commandRejected);

  FibsDiagnostics recordCookie(CookieMessage cm) => FibsDiagnostics(
    cookieCount: cookieCount + 1,
    lastCookie: cm.cookie,
    protocolSignalCount: protocolSignalCount,
    lastProtocolSignals: lastProtocolSignals,
    protocolMatchResultCount: protocolMatchResultCount,
    lastProtocolMatchResult: lastProtocolMatchResult,
    whoInfoCookieCount:
        whoInfoCookieCount + (cm.cookie == FibsCookie.CLIP_WHO_INFO ? 1 : 0),
    whoListComplete: whoListComplete || cm.cookie == FibsCookie.CLIP_WHO_END,
  );

  FibsDiagnostics recordTransition(FibsProtocolTransition transition) =>
      FibsDiagnostics(
        cookieCount: cookieCount,
        lastCookie: lastCookie,
        protocolSignalCount:
            protocolSignalCount + (transition.signals.isEmpty ? 0 : 1),
        lastProtocolSignals: transition.signals.isEmpty
            ? const {}
            : Set.unmodifiable(transition.signals),
        protocolMatchResultCount:
            protocolMatchResultCount + (transition.matchResult == null ? 0 : 1),
        lastProtocolMatchResult:
            transition.matchResult ?? lastProtocolMatchResult,
        whoInfoCookieCount: whoInfoCookieCount,
        whoListComplete: whoListComplete,
      );

  FibsDiagnostics reset() => const FibsDiagnostics();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FibsDiagnostics &&
          cookieCount == other.cookieCount &&
          lastCookie == other.lastCookie &&
          protocolSignalCount == other.protocolSignalCount &&
          _sameSignals(lastProtocolSignals, other.lastProtocolSignals) &&
          protocolMatchResultCount == other.protocolMatchResultCount &&
          lastProtocolMatchResult == other.lastProtocolMatchResult &&
          whoInfoCookieCount == other.whoInfoCookieCount &&
          whoListComplete == other.whoListComplete;

  @override
  int get hashCode => Object.hash(
    cookieCount,
    lastCookie,
    protocolSignalCount,
    Object.hashAllUnordered(lastProtocolSignals),
    protocolMatchResultCount,
    lastProtocolMatchResult,
    whoInfoCookieCount,
    whoListComplete,
  );

  static bool _sameSignals(
    Set<FibsProtocolSignal> a,
    Set<FibsProtocolSignal> b,
  ) => a.length == b.length && a.containsAll(b);
}
