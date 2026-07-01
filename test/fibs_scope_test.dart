import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #4 decoupling: the FIBS views read their FibsState from FibsScope (injected
  // by FibsPage), not a global. This pins the mechanism: FibsScope.of returns
  // exactly the instance the scope was given -- and a DIFFERENT, unrelated
  // instance is never handed out -- so a view under it is driven by the
  // injected state.
  testWidgets('FibsScope.of returns exactly the injected FibsState', (
    tester,
  ) async {
    final other = FibsState();
    final scoped = FibsState();

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
    expect(seen, isNot(same(other))); // never some other instance
  });
}
