import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #4 decoupling: the FIBS views read their FibsState from FibsScope (injected
  // by FibsPage), not the App.fibs global. This pins the mechanism:
  // FibsScope.of returns the SCOPED instance even when App.fibs is a different
  // one, so a view under it is driven by the injected state, not the singleton.
  testWidgets('FibsScope.of returns the scoped FibsState, not App.fibs', (
    tester,
  ) async {
    final global = FibsState();
    final scoped = FibsState();
    App.fibs = global; // the global that views used to reach for directly

    late FibsState seen;
    await tester.pumpWidget(
      FibsScope(
        fibs: scoped,
        child: Builder(
          builder: (context) {
            seen = FibsScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen, same(scoped)); // the injected instance
    expect(seen, isNot(same(global))); // NOT the global
  });
}
