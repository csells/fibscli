part of 'fibs_state.dart';

const _resumeRejectedCookies = {
  FibsCookie.FIBS_NoSavedMatch,
  FibsCookie.FIBS_NoOne,
  FibsCookie.FIBS_NoUser,
  FibsCookie.FIBS_PlayerRefusingGames,
  FibsCookie.FIBS_AlreadyPlaying,
  FibsCookie.FIBS_DidntInvite,
  FibsCookie.FIBS_DontKnowUser,
  FibsCookie.FIBS_NotPlaying,
  FibsCookie.FIBS_NotWatchingPlaying,
};

@immutable
class ResumeDelayInfo {
  const ResumeDelayInfo({
    required this.opponent,
    required this.minutes,
    required this.receivedAt,
  });

  final String opponent;
  final int minutes;
  final DateTime receivedAt;

  DateTime get retryAfter => receivedAt.add(Duration(minutes: minutes));

  bool isActive(DateTime now) => now.isBefore(retryAfter);

  String get durationLabel => minutes == 1 ? '1 minute' : '$minutes minutes';

  String get detail => 'will not attempt to resume for $durationLabel';

  String get sentence => '$opponent $detail.';
}

class _FibsResumeState {
  final _delays = <String, ResumeDelayInfo>{};
  final _attempts = <String>{};
  final _parkedKeys = <String>{};

  bool ignoreBoardsUntilUserAction = false;
  bool captureUnsolicitedLoginBoard = false;

  static final _delayPattern = RegExp(
    r'^I will not attempt to resume for (?<minutes>[0-9]+) minutes?\.$',
  );

  static String key(String opponent) => opponent.toLowerCase();

  ResumeDelayInfo? delayFor(String opponent) {
    final delay = _delays[key(opponent)];
    if (delay == null || !delay.isActive(DateTime.now())) return null;
    return delay;
  }

  bool pendingFor(String opponent) => _attempts.contains(key(opponent));

  bool get hasPendingAttempt => _attempts.isNotEmpty;

  void reset() {
    ignoreBoardsUntilUserAction = false;
    captureUnsolicitedLoginBoard = false;
    _delays.clear();
    _attempts.clear();
    _parkedKeys.clear();
  }

  void startLoginDiscovery() {
    ignoreBoardsUntilUserAction = true;
    captureUnsolicitedLoginBoard = true;
    _delays.clear();
    _attempts.clear();
    _parkedKeys.clear();
  }

  void allowBoardAdmission() {
    ignoreBoardsUntilUserAction = false;
    captureUnsolicitedLoginBoard = false;
  }

  void suppressBoards() {
    ignoreBoardsUntilUserAction = true;
    captureUnsolicitedLoginBoard = false;
  }

  void beginAttempt(String opponent) {
    allowBoardAdmission();
    final opponentKey = key(opponent);
    _parkedKeys.remove(opponentKey);
    _delays.remove(opponentKey);
    _attempts.add(opponentKey);
  }

  void markAttemptWaitingForBoard(String opponent) {
    _attempts.add(key(opponent));
  }

  bool shouldJoinPromptFrom(String? opponent) =>
      opponent != null && _attempts.contains(key(opponent));

  bool isUnsolicitedResume(String? opponent) {
    if (!ignoreBoardsUntilUserAction) return false;
    if (opponent == null || opponent.isEmpty) return true;
    return !_attempts.contains(key(opponent));
  }

  bool markParked(String? opponent) {
    final opponentKey = opponent == null || opponent.isEmpty
        ? null
        : key(opponent);
    captureUnsolicitedLoginBoard = false;
    if (opponentKey != null) {
      _delays.remove(opponentKey);
      _attempts.remove(opponentKey);
    }
    return opponentKey == null || _parkedKeys.add(opponentKey);
  }

  void recordDelay(ResumeDelayInfo delay) {
    final opponentKey = key(delay.opponent);
    _delays[opponentKey] = delay;
    _attempts.remove(opponentKey);
  }

  bool clearRejected(FibsCookie cookie) {
    final cleared =
        _resumeRejectedCookies.contains(cookie) && _attempts.isNotEmpty;
    if (cleared) _attempts.clear();
    return cleared;
  }

  void clearDelayForCookie(CookieMessage cm) {
    final opponent = switch (cm.cookie) {
      FibsCookie.FIBS_ResumeMatchAck0 ||
      FibsCookie.FIBS_ResumeMatchAck5 => cm.crumbOrNull(FibsCrumbKeys.opponent),
      FibsCookie.FIBS_ResumeMatchRequest => cm.crumbOrNull(FibsCrumbKeys.name),
      _ => null,
    };
    if (opponent != null) _delays.remove(key(opponent));
  }

  void clearAttemptForCookie(CookieMessage cm) {
    if (cm.cookie == FibsCookie.FIBS_Board ||
        cm.cookie == FibsCookie.FIBS_NoSavedGames) {
      _attempts.clear();
      return;
    }
    final opponent = switch (cm.cookie) {
      FibsCookie.FIBS_ResumeMatchAck0 ||
      FibsCookie.FIBS_ResumeMatchAck5 => cm.crumbOrNull(FibsCrumbKeys.opponent),
      _ => null,
    };
    if (opponent != null) _attempts.remove(key(opponent));
  }

  static ResumeDelayInfo? parseDelay(String opponent, String message) {
    final match = _delayPattern.firstMatch(message);
    if (match == null) return null;
    final minutes = int.tryParse(match.namedGroup('minutes') ?? '');
    if (minutes == null) return null;
    return ResumeDelayInfo(
      opponent: opponent,
      minutes: minutes,
      receivedAt: DateTime.now(),
    );
  }
}
