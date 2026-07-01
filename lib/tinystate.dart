import 'package:flutter/material.dart';

class ChangeNotifierBuilder<T extends ChangeNotifier?> extends AnimatedBuilder {
  ChangeNotifierBuilder({
    required T notifier,
    required Widget Function(BuildContext context, T listenable, Widget? child)
    builder,
    super.key,
    super.child,
  }) : super(
         animation: notifier!,
         builder: (context, child) => builder(context, notifier, child),
       );
}

class NotifierList<T> extends Iterable<T> with ChangeNotifier {
  NotifierList([List<T>? items]) : _items = items ?? <T>[];
  final List<T> _items;

  T operator [](int i) => _items[i];

  T add(T value) {
    _items.add(value);
    notifyListeners();
    return value;
  }

  void addAll(Iterable<T> values) {
    _items.addAll(values);
    notifyListeners();
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

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  int get length => _items.length;

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
