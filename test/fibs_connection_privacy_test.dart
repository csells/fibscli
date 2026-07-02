import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FIBS connection source contains no raw protocol console logging', () {
    final source = File(
      'packages/fibscli_lib/lib/src/fibs_connection.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('dart:developer')));
    expect(source, isNot(contains('dev.log')));
    expect(source, isNot(contains('SEND:')));
    expect(source, isNot(contains('RECEIVE:')));
    expect(source, isNot(contains('stream.message')));
  });
}
