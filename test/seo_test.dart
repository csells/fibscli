import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('robots.txt', () {
    test('allows crawling and points at the sitemap', () {
      final robots = File('web/robots.txt').readAsStringSync();
      expect(robots, contains('User-agent: *'));
      expect(robots, isNot(contains('Disallow: /')));
      expect(robots, contains('Sitemap: https://playfibs.com/sitemap.xml'));
    });
  });

  group('sitemap.xml', () {
    test('lists the canonical homepage', () {
      final sitemap = File('web/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('<?xml'));
      expect(
        sitemap,
        contains('xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'),
      );
      expect(sitemap, contains('<loc>https://playfibs.com/</loc>'));
    });
  });

  group('index.html SEO metadata', () {
    final html = File('web/index.html').readAsStringSync();

    test('declares the document language', () {
      expect(html, contains('<html lang="en">'));
    });

    test('canonicalizes every route to the apex homepage', () {
      expect(
        html,
        contains('<link rel="canonical" href="https://playfibs.com/">'),
      );
    });

    test('has a descriptive title and a substantial description', () {
      final title = RegExp('<title>([^<]+)</title>').firstMatch(html)?.group(1);
      expect(title, isNotNull);
      expect(title!.toLowerCase(), contains('backgammon'));
      final description = RegExp(
        '<meta name="description" content="([^"]+)"',
      ).firstMatch(html)?.group(1);
      expect(description, isNotNull);
      expect(
        description!.length,
        inInclusiveRange(50, 160),
        reason: 'meta description should fill a search snippet, not overflow',
      );
    });

    test('carries Open Graph tags with an absolute image URL', () {
      for (final property in [
        'og:title',
        'og:description',
        'og:url',
        'og:site_name',
      ]) {
        expect(html, contains('property="$property"'));
      }
      expect(html, contains('<meta property="og:type" content="website">'));
      expect(
        html,
        contains(
          '<meta property="og:image" '
          'content="https://playfibs.com/og-image.png">',
        ),
      );
    });

    test('carries a Twitter summary card', () {
      expect(
        html,
        contains('<meta name="twitter:card" content="summary_large_image">'),
      );
    });

    test('embeds valid JSON-LD describing the app', () {
      final jsonLd = RegExp(
        r'<script type="application/ld\+json">(.*?)</script>',
        dotAll: true,
      ).firstMatch(html)?.group(1);
      expect(jsonLd, isNotNull, reason: 'JSON-LD block must exist');
      final decoded = json.decode(jsonLd!) as Map<String, dynamic>;
      expect(decoded['@context'], 'https://schema.org');
      expect(decoded['@type'], 'WebApplication');
      expect(decoded['name'], 'playfibs');
      expect(decoded['url'], 'https://playfibs.com/');
      expect(decoded['applicationCategory'], 'GameApplication');
    });

    test('offers crawlable body content that yields to the app', () {
      final body = html.substring(html.indexOf('<body>'));
      expect(body, contains('<h1>'));
      expect(
        RegExp('<h1>([^<]+)</h1>').firstMatch(body)?.group(1)?.toLowerCase(),
        contains('backgammon'),
      );
      expect(body, contains('<noscript>'));
      expect(
        body,
        contains("addEventListener('flutter-first-frame'"),
        reason: 'static content must be removed when the app renders',
      );
    });
  });

  group('og-image.png', () {
    test('is a real 1200x630 PNG', () {
      final bytes = File('web/og-image.png').readAsBytesSync();
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ], reason: 'PNG magic bytes');
      int be32(int offset) =>
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      expect(be32(16), 1200, reason: 'IHDR width');
      expect(be32(20), 630, reason: 'IHDR height');
    });
  });
}
