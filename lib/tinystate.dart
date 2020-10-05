import 'package:flutter/widgets.dart';
import 'package:dartx/dartx.dart';

class ChangeNotifierBuilder<T extends ChangeNotifier> extends AnimatedBuilder {
  ChangeNotifierBuilder({
    Key key,
    @required T notifier,
    @required Widget Function(BuildContext context, T listenable, Widget child) build,
    Widget child,
  }) : super(
            key: key,
            animation: notifier,
            child: child,
            builder: (context, child) => build(context, notifier, child));
}

class NotifierList<T> extends Iterable<T> with ChangeNotifier {
  final List<T> _items;
  NotifierList([List<T> items]) : _items = items ?? <T>[];

  T operator [](int i) => _items[i];
  void operator []=(int i, T value) => _items[i] = value;

  T add(T value) {
    _items.add(value);
    notifyListeners();
    return value;
  }

  void addAll(Iterable<T> values) {
    _items.addAll(values);
    notifyListeners();
  }

  T insert(int index, T element) {
    _items.insert(index, element);
    notifyListeners();
    return element;
  }

  T remove(T value) {
    _items.remove(value);
    notifyListeners();
    return value;
  }

  T removeAt(int index) {
    final value = _items.removeAt(index);
    notifyListeners();
    return value;
  }

  int indexOf(T value) => _items.indexOf(value);

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  int get length => _items.length;

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Iterable<T> sortedBy(Comparable Function(T element) selector) => _items.sortedBy(selector);
}
