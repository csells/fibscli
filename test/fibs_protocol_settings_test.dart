import 'package:fibscli/fibs_protocol_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings negotiation enables required FIBS options once', () {
    const settings = FibsProtocolSettings();

    final first = settings.negotiate(doublePrompt: '0', moreboards: '0');
    final second = first.state.negotiate(doublePrompt: '0', moreboards: '0');

    expect(first.commands, ['toggle double', 'toggle moreboards']);
    expect(second.commands, isEmpty);
  });

  test(
    'settings negotiation resets guards when FIBS reports options enabled',
    () {
      const settings = FibsProtocolSettings();
      final toggled = settings
          .negotiate(doublePrompt: '0', moreboards: '0')
          .state;
      final reset = toggled.negotiate(doublePrompt: '1', moreboards: '1').state;

      final offAgain = reset.negotiate(doublePrompt: '0', moreboards: '0');

      expect(offAgain.commands, ['toggle double', 'toggle moreboards']);
    },
  );

  test('settings negotiation leaves unknown option crumbs alone', () {
    final transition = const FibsProtocolSettings().negotiate(
      doublePrompt: null,
      moreboards: null,
    );

    expect(transition.state, const FibsProtocolSettings());
    expect(transition.commands, isEmpty);
  });
}
