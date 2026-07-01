import 'package:fibscli/tinystate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotifierList', () {
    test('notifies on every mutation', () {
      final list = NotifierList<int>();
      var n = 0;
      list.addListener(() => n++);

      list.add(1);
      expect(n, 1);
      list.addAll([2, 3]);
      expect(n, 2);
      list.remove(2);
      expect(n, 3);
      list.removeAt(0);
      expect(n, 4);
      list.clear();
      expect(n, 5);
    });

    test('is an iterable view over its items', () {
      final list = NotifierList<String>(['a', 'b']);
      expect(list.length, 2);
      expect(list[0], 'a');
      expect(list.toList(), ['a', 'b']);
      expect(list.contains('b'), isTrue);

      list.add('c');
      expect(list.last, 'c');
      expect(list.length, 3);
    });

    test('add/remove/removeAt return the affected value', () {
      final list = NotifierList<int>();
      expect(list.add(5), 5);
      expect(list.add(6), 6);
      expect(list.removeAt(0), 5);
      expect(list.remove(6), 6);
      expect(list, isEmpty);
    });
  });

  testWidgets('ChangeNotifierBuilder rebuilds when the notifier fires', (
    tester,
  ) async {
    final list = NotifierList<int>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierBuilder<NotifierList<int>>(
          notifier: list,
          builder: (context, l, child) => Text('count=${l.length}'),
        ),
      ),
    );
    expect(find.text('count=0'), findsOneWidget);

    list.add(1);
    await tester.pump();
    expect(find.text('count=1'), findsOneWidget); // rebuilt on notify
  });
}
