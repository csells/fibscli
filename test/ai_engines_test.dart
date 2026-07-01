import 'package:fibscli/ai_engines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The gnubg engine is offered only when a service URL is configured, so a
  // build with no gnubg-service doesn't list an engine that can't work.
  test('gnubgFactoryFor builds a factory when a URL is configured', () {
    final factory = gnubgFactoryFor('https://gnubg.example', apiKey: 'k');
    expect(factory, isNotNull);
    expect(factory!.name.toLowerCase(), contains('gnubg'));
  });

  test('gnubgFactoryFor returns null with no URL (engine stays hidden)', () {
    expect(gnubgFactoryFor(''), isNull);
  });
}
