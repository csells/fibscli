import 'package:flutter/foundation.dart';

@immutable
class FibsProtocolSettings {
  const FibsProtocolSettings({
    this.doublePromptToggleSent = false,
    this.moreboardsToggleSent = false,
  });

  final bool doublePromptToggleSent;
  final bool moreboardsToggleSent;

  FibsProtocolSettingsTransition negotiate({
    required String? doublePrompt,
    required String? moreboards,
  }) {
    final commands = <String>[];
    var nextDoublePromptToggleSent = doublePromptToggleSent;
    var nextMoreboardsToggleSent = moreboardsToggleSent;

    if (doublePrompt == '1') {
      nextDoublePromptToggleSent = false;
    } else if (doublePrompt == '0' && !nextDoublePromptToggleSent) {
      nextDoublePromptToggleSent = true;
      commands.add('toggle double');
    }

    if (moreboards == '1') {
      nextMoreboardsToggleSent = false;
    } else if (moreboards == '0' && !nextMoreboardsToggleSent) {
      nextMoreboardsToggleSent = true;
      commands.add('toggle moreboards');
    }

    return FibsProtocolSettingsTransition(
      state: FibsProtocolSettings(
        doublePromptToggleSent: nextDoublePromptToggleSent,
        moreboardsToggleSent: nextMoreboardsToggleSent,
      ),
      commands: commands,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FibsProtocolSettings &&
          doublePromptToggleSent == other.doublePromptToggleSent &&
          moreboardsToggleSent == other.moreboardsToggleSent;

  @override
  int get hashCode => Object.hash(doublePromptToggleSent, moreboardsToggleSent);
}

@immutable
class FibsProtocolSettingsTransition {
  const FibsProtocolSettingsTransition({
    required this.state,
    required this.commands,
  });

  final FibsProtocolSettings state;
  final List<String> commands;
}
