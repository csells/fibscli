import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/index.html', () {
    final html = File('web/index.html').readAsStringSync();

    test('carries the Cloudflare Web Analytics beacon with a real token', () {
      final beacon = RegExp(
        '<script'
        r'\s+defer'
        r'\s+src="https://static\.cloudflareinsights\.com/beacon\.min\.js"'
        r'''\s+data-cf-beacon='\{"token": "([0-9a-f]{32})"\}'>'''
        '</script>',
      );
      expect(
        beacon.hasMatch(html),
        isTrue,
        reason:
            'index.html must include the deferred Cloudflare Web Analytics '
            'beacon with a concrete 32-hex site token',
      );
    });

    test('still refuses service workers', () {
      expect(html, contains('serviceWorker'));
      expect(html, contains('unregister'));
    });
  });
}
