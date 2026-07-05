import 'fibs_lobby.dart';
import 'fibs_resume_coordinator.dart';
import 'fibs_session.dart';

enum SavedMatchDisplayState {
  delayed,
  pending,
  requested,
  activeWithUser,
  busy,
  ready,
  checking,
  unavailable,
  saved,
}

class SavedMatchDisplay {
  const SavedMatchDisplay({
    required this.match,
    required this.state,
    required this.canResume,
    required this.subtitle,
    required this.actionLabel,
    this.note,
  });

  final SavedMatchInfo match;
  final SavedMatchDisplayState state;
  final bool canResume;
  final String subtitle;
  final String actionLabel;
  final String? note;
}

SavedMatchDisplay savedMatchDisplayFor({
  required SavedMatchInfo match,
  required String? currentUser,
  required bool resumePending,
  required bool resumeRequested,
  required ResumeDelayInfo? resumeDelay,
  required WhoInfo? who,
}) {
  final score = match.scoreLabel;
  if (resumeDelay != null) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.delayed,
      canResume: false,
      subtitle: _savedMatchSubtitle('Resume delayed', score),
      actionLabel: 'Waiting',
      note: resumeDelay.sentence,
    );
  }
  if (resumePending) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.pending,
      canResume: false,
      subtitle: _savedMatchSubtitle('Resuming', score),
      actionLabel: 'Waiting',
      note: "Waiting for FIBS to load ${match.opponent}'s board",
    );
  }
  if (resumeRequested) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.requested,
      canResume: true,
      subtitle: _savedMatchSubtitle('Ready now', score, 'tap Resume'),
      actionLabel: 'Resume',
      note: '${match.opponent} asked to resume this match',
    );
  }
  if (_whoIsPlayingCurrentUser(who, currentUser)) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.activeWithUser,
      canResume: true,
      subtitle: _savedMatchSubtitle('Active with you', score, 'tap Resume'),
      actionLabel: 'Resume',
      note: '${who!.user} is playing you',
    );
  }
  if (who != null && who.opponent.isNotEmpty) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.busy,
      canResume: false,
      subtitle: _savedMatchSubtitle('Busy right now', score),
      actionLabel: 'Waiting',
      note: '${who.user} is playing ${who.opponent}',
    );
  }
  if (who != null) {
    if (_whoCanResume(who)) {
      return SavedMatchDisplay(
        match: match,
        state: SavedMatchDisplayState.ready,
        canResume: true,
        subtitle: _savedMatchSubtitle('Ready now', score, 'tap Resume'),
        actionLabel: 'Resume',
      );
    }
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.busy,
      canResume: false,
      subtitle: _savedMatchSubtitle('Busy right now', score),
      actionLabel: 'Waiting',
      note: '${who.user} is online but not ready to resume',
    );
  }
  if (match.isReady) {
    return SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.checking,
      canResume: false,
      subtitle: _savedMatchSubtitle('Checking availability', score),
      actionLabel: 'Waiting',
      note: 'Waiting for FIBS to confirm ${match.opponent} is ready',
    );
  }
  return switch (match.availability) {
    SavedMatchAvailability.online => SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.busy,
      canResume: false,
      subtitle: _savedMatchSubtitle('Busy right now', score),
      actionLabel: 'Waiting',
      note: '${match.opponent} is online but not ready to resume',
    ),
    SavedMatchAvailability.offline => SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.unavailable,
      canResume: false,
      subtitle: _savedMatchSubtitle('Unavailable', score),
      actionLabel: 'Offline',
      note: '${match.opponent} is offline',
    ),
    SavedMatchAvailability.unknown => SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.saved,
      canResume: false,
      subtitle: _savedMatchSubtitle('Saved', score),
      actionLabel: 'Waiting',
      note: 'Waiting for FIBS to report opponent status',
    ),
    SavedMatchAvailability.ready => SavedMatchDisplay(
      match: match,
      state: SavedMatchDisplayState.checking,
      canResume: false,
      subtitle: _savedMatchSubtitle('Checking availability', score),
      actionLabel: 'Waiting',
      note: 'Waiting for FIBS to confirm ${match.opponent} is ready',
    ),
  };
}

bool _whoCanResume(WhoInfo? who) =>
    who != null && who.ready && who.opponent.isEmpty;

bool _whoIsPlayingCurrentUser(WhoInfo? who, String? currentUser) =>
    who != null &&
    currentUser != null &&
    who.opponent.toLowerCase() == currentUser.toLowerCase();

String _savedMatchSubtitle(String status, String? score, [String? action]) =>
    [status, if (score != null) score, if (action != null) action].join(' · ');
