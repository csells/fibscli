import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PWA manifest (issue #13)', () {
    test('locks the installed app to landscape', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      // "landscape" allows either landscape rotation but excludes portrait;
      // "landscape-primary" would pin to a single orientation.
      expect(manifest['orientation'], 'landscape');
      expect(manifest['display'], 'standalone');
    });
  });
}
