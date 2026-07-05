import 'package:fibscli/fibs_protocol_routing.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cookie route table classifies protocol-owned cookies', () {
    expect(
      fibsProtocolRouteFor(FibsCookie.FIBS_Board),
      FibsProtocolCookieRoute.protocol,
    );
    expect(
      fibsProtocolRouteFor(FibsCookie.FIBS_BadMove),
      FibsProtocolCookieRoute.protocol,
    );
    expect(
      fibsProtocolRouteFor(FibsCookie.FIBS_NoSavedMatch),
      FibsProtocolCookieRoute.protocol,
    );
    expect(
      fibsProtocolRouteFor(FibsCookie.FIBS_OpponentLeftGame),
      FibsProtocolCookieRoute.protocol,
    );
    expect(
      fibsProtocolRouteFor(FibsCookie.CLIP_SAYS),
      FibsProtocolCookieRoute.protocol,
    );
  });

  test('cookie route table ignores lobby roster rows', () {
    expect(
      fibsProtocolRouteFor(FibsCookie.CLIP_WHO_INFO),
      FibsProtocolCookieRoute.ignore,
    );
  });
}
