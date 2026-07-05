import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_crumb_keys.dart';

@immutable
class FibsProtocolMessage {
  const FibsProtocolMessage({
    required this.cookie,
    required this.from,
    required this.text,
  });

  final FibsCookie cookie;
  final String from;
  final String text;
}

@immutable
class FibsProtocolMatchResult {
  const FibsProtocolMatchResult({required this.didIWin, required this.message});

  final bool didIWin;
  final String message;
}

FibsProtocolMessage fibsProtocolChatMessage(CookieMessage cm) {
  final from =
      cm.crumbOrNull(FibsCrumbKeys.name) ??
      cm.crumbOrNull(FibsCrumbKeys.from) ??
      'FIBS';
  return FibsProtocolMessage(
    cookie: cm.cookie,
    from: from,
    text: cm.crumb(FibsCrumbKeys.message),
  );
}

FibsProtocolMessage fibsProtocolSystemMessage(CookieMessage cm) =>
    FibsProtocolMessage(
      cookie: cm.cookie,
      from: 'FIBS',
      text: _displayMessage(cm),
    );

FibsProtocolMatchResult? fibsProtocolMatchResult(CookieMessage cm) =>
    switch (cm.cookie) {
      FibsCookie.FIBS_YouWinMatch => FibsProtocolMatchResult(
        didIWin: true,
        message: _resultText(cm),
      ),
      FibsCookie.FIBS_PlayerWinsMatch => FibsProtocolMatchResult(
        didIWin: false,
        message: _resultText(cm),
      ),
      _ => null,
    };

String _displayMessage(CookieMessage cm) {
  final text =
      cm.crumbOrNull(FibsCrumbKeys.message) ?? cm.crumbOrNull('raw') ?? cm.raw;
  return text.replaceFirst(RegExp(r'^\*\*\s*'), '');
}

String _resultText(CookieMessage cm) {
  final compact = cm.raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return compact.replaceAllMapped(RegExp(r'\s+([.!?,])'), (m) => m[1]!);
}
