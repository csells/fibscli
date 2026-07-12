import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('privacy page', () {
    Future<Iterable<String>> pumpAndCollectBodies(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPage()));
      await tester.pumpAndSettle();
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '');
    }

    testWidgets('hosting section names Cloudflare, not Firebase', (
      tester,
    ) async {
      final bodies = await pumpAndCollectBodies(tester);
      expect(
        bodies.any((t) => t.contains('Cloudflare serves the web app')),
        isTrue,
        reason: 'hosting copy must say Cloudflare serves the web app',
      );
      expect(
        bodies.any((t) => t.contains('Firebase')),
        isFalse,
        reason: 'Firebase no longer hosts the app',
      );
    });

    testWidgets('discloses cookieless Cloudflare Web Analytics', (
      tester,
    ) async {
      final bodies = await pumpAndCollectBodies(tester);
      expect(
        bodies.any((t) => t.contains('Cloudflare Web Analytics')),
        isTrue,
        reason: 'visitor analytics must be disclosed by name',
      );
      expect(
        bodies.any(
          (t) =>
              t.contains('Cloudflare Web Analytics') &&
              t.contains('cookies') &&
              t.contains('across sites'),
        ),
        isTrue,
        reason: 'disclosure must state no cookies and no cross-site tracking',
      );
    });
  });
}
