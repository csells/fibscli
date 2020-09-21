import 'package:flutter/widgets.dart';

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
