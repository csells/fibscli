import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:dartx/dartx.dart';

class ChangeNotifierBuilder<T extends ChangeNotifier> extends AnimatedBuilder {
  ChangeNotifierBuilder({
    Key key,
    @required T notifier,
    @required Widget Function(BuildContext context, T listenable, Widget child) builder,
    Widget child,
  }) : super(
            key: key,
            animation: notifier,
            child: child,
            builder: (context, child) => builder(context, notifier, child));
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

class FutureBuilder2<T> extends StatelessWidget {
  final Future<T> future;
  final T initialData;
  final Widget Function(BuildContext context) pending;
  final Widget Function(BuildContext context, Object error) error;
  final Widget Function(BuildContext context, T data) data;

  FutureBuilder2({
    Key key,
    @required this.future,
    this.initialData,
    this.pending,
    this.error,
    @required this.data,
  })  : assert(data != null),
        super(key: key);

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) return error != null ? error(context, snapshot.error) : Text(snapshot.error.toString());
        if (snapshot.hasData) return data(context, snapshot.data);
        return pending != null ? pending(context) : Center(child: CircularProgressIndicator());
      });
}
