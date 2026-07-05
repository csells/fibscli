import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_crumb_keys.dart';

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

enum FibsResumeBoardAction { admit, ignore, park }

@immutable
class FibsResumeBoardDecision {
  const FibsResumeBoardDecision._({
    required this.action,
    required this.resume,
    this.opponent,
    this.refreshSavedGames = false,
  });

  const FibsResumeBoardDecision.admit(FibsResumeCoordinator resume)
    : this._(action: FibsResumeBoardAction.admit, resume: resume);

  const FibsResumeBoardDecision.ignore(FibsResumeCoordinator resume)
    : this._(action: FibsResumeBoardAction.ignore, resume: resume);

  const FibsResumeBoardDecision.park({
    required FibsResumeCoordinator resume,
    required String? opponent,
    required bool refreshSavedGames,
  }) : this._(
         action: FibsResumeBoardAction.park,
         resume: resume,
         opponent: opponent,
         refreshSavedGames: refreshSavedGames,
       );

  final FibsResumeBoardAction action;
  final FibsResumeCoordinator resume;
  final String? opponent;
  final bool refreshSavedGames;
}

enum FibsResumeAckAction { park, requestBoard }

@immutable
class FibsResumeAckDecision {
  const FibsResumeAckDecision._({
    required this.action,
    required this.resume,
    this.opponent,
    this.refreshSavedGames = false,
  });

  const FibsResumeAckDecision.park({
    required FibsResumeCoordinator resume,
    required String? opponent,
    required bool refreshSavedGames,
  }) : this._(
         action: FibsResumeAckAction.park,
         resume: resume,
         opponent: opponent,
         refreshSavedGames: refreshSavedGames,
       );

  const FibsResumeAckDecision.requestBoard({
    required FibsResumeCoordinator resume,
    required String? opponent,
  }) : this._(
         action: FibsResumeAckAction.requestBoard,
         resume: resume,
         opponent: opponent,
       );

  final FibsResumeAckAction action;
  final FibsResumeCoordinator resume;
  final String? opponent;
  final bool refreshSavedGames;
}

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

@immutable
class FibsResumeParkResult {
  const FibsResumeParkResult({
    required this.resume,
    required this.refreshSavedGames,
  });

  final FibsResumeCoordinator resume;
  final bool refreshSavedGames;
}

@immutable
class FibsResumeRejectedResult {
  const FibsResumeRejectedResult({required this.resume, required this.cleared});

  final FibsResumeCoordinator resume;
  final bool cleared;
}

enum FibsResumeMode { idle, loginDiscovery, suppressingBoards, attempting }

const _pendingOpponentUnchanged = Object();

class FibsResumeCoordinator {
  const FibsResumeCoordinator()
    : _delays = const {},
      _parkedKeys = const {},
      _pendingOpponent = null,
      mode = FibsResumeMode.idle;

  FibsResumeCoordinator._({
    required Map<String, ResumeDelayInfo> delays,
    required Set<String> parkedKeys,
    required this._pendingOpponent,
    required this.mode,
  }) : _delays = Map.unmodifiable(delays),
       _parkedKeys = Set.unmodifiable(parkedKeys);

  final Map<String, ResumeDelayInfo> _delays;
  final Set<String> _parkedKeys;
  final String? _pendingOpponent;
  final FibsResumeMode mode;

  static final _delayPattern = RegExp(
    r'^I will not attempt to resume for (?<minutes>[0-9]+) minutes?\.$',
  );

  static String key(String opponent) => opponent.toLowerCase();

  ResumeDelayInfo? delayFor(String opponent) {
    final delay = _delays[key(opponent)];
    if (delay == null || !delay.isActive(DateTime.now())) return null;
    return delay;
  }

  bool pendingFor(String opponent) => _pendingOpponent == key(opponent);

  bool get hasPendingAttempt => _pendingOpponent != null;

  FibsResumeCoordinator reset() => const FibsResumeCoordinator();

  FibsResumeCoordinator startLoginDiscovery() => FibsResumeCoordinator._(
    delays: const {},
    parkedKeys: const {},
    pendingOpponent: null,
    mode: FibsResumeMode.loginDiscovery,
  );

  FibsResumeCoordinator allowBoardAdmission() =>
      _copyWith(mode: FibsResumeMode.idle, pendingOpponent: null);

  FibsResumeCoordinator suppressBoards() =>
      _copyWith(mode: FibsResumeMode.suppressingBoards, pendingOpponent: null);

  FibsResumeCoordinator beginAttempt(String opponent) {
    final opponentKey = key(opponent);
    return _copyWith(
      delays: {..._delays}..remove(opponentKey),
      parkedKeys: {..._parkedKeys}..remove(opponentKey),
      pendingOpponent: opponentKey,
      mode: FibsResumeMode.attempting,
    );
  }

  FibsResumeCoordinator markAttemptWaitingForBoard(String opponent) =>
      _copyWith(
        pendingOpponent: key(opponent),
        mode: FibsResumeMode.attempting,
      );

  bool shouldJoinPromptFrom(String? opponent) =>
      opponent != null && pendingFor(opponent);

  bool isUnsolicitedResume(String? opponent) {
    if (!_isSuppressingIncomingBoards) return false;
    if (opponent == null || opponent.isEmpty) return true;
    return !pendingFor(opponent);
  }

  bool get _isSuppressingIncomingBoards =>
      mode == FibsResumeMode.loginDiscovery ||
      mode == FibsResumeMode.suppressingBoards;

  FibsResumeBoardDecision decideBoard({
    required String? opponent,
    required bool hasSessionBoard,
  }) {
    if (!_isSuppressingIncomingBoards || hasSessionBoard) {
      return FibsResumeBoardDecision.admit(this);
    }
    if (mode == FibsResumeMode.suppressingBoards) {
      return FibsResumeBoardDecision.ignore(this);
    }
    final parked = markParked(opponent);
    return FibsResumeBoardDecision.park(
      resume: parked.resume,
      opponent: opponent,
      refreshSavedGames: parked.refreshSavedGames,
    );
  }

  FibsResumeAckDecision acceptResumeAcknowledgement(String? opponent) {
    final cleared = clearDelayForOpponent(opponent);
    if (cleared.isUnsolicitedResume(opponent)) {
      final parked = cleared.markParked(opponent);
      return FibsResumeAckDecision.park(
        resume: parked.resume,
        opponent: opponent,
        refreshSavedGames: parked.refreshSavedGames,
      );
    }
    final next = opponent == null
        ? cleared
        : cleared.markAttemptWaitingForBoard(opponent);
    return FibsResumeAckDecision.requestBoard(resume: next, opponent: opponent);
  }

  FibsResumeParkResult markParked(String? opponent) {
    final opponentKey = opponent == null || opponent.isEmpty
        ? null
        : key(opponent);
    final delays = {..._delays};
    final parkedKeys = {..._parkedKeys};
    var refreshSavedGames = opponentKey == null;
    if (opponentKey != null) {
      delays.remove(opponentKey);
      refreshSavedGames = parkedKeys.add(opponentKey);
    }
    return FibsResumeParkResult(
      resume: _copyWith(
        delays: delays,
        parkedKeys: parkedKeys,
        pendingOpponent: _pendingOpponent == opponentKey
            ? null
            : _pendingOpponent,
        mode: mode == FibsResumeMode.loginDiscovery
            ? FibsResumeMode.suppressingBoards
            : mode,
      ),
      refreshSavedGames: refreshSavedGames,
    );
  }

  FibsResumeCoordinator recordDelay(ResumeDelayInfo delay) {
    final opponentKey = key(delay.opponent);
    return _copyWith(
      delays: {..._delays, opponentKey: delay},
      pendingOpponent: _pendingOpponent == opponentKey
          ? null
          : _pendingOpponent,
      mode: _pendingOpponent == opponentKey && mode == FibsResumeMode.attempting
          ? FibsResumeMode.idle
          : mode,
    );
  }

  FibsResumeRejectedResult clearRejected(FibsCookie cookie) {
    final cleared =
        _resumeRejectedCookies.contains(cookie) && _pendingOpponent != null;
    return FibsResumeRejectedResult(
      resume: cleared ? _clearPendingAttempt() : this,
      cleared: cleared,
    );
  }

  FibsResumeCoordinator clearDelayForOpponent(String? opponent) {
    if (opponent == null) return this;
    final delays = {..._delays}..remove(key(opponent));
    return _copyWith(delays: delays);
  }

  FibsResumeCoordinator clearDelayForCookie(CookieMessage cm) {
    final opponent = switch (cm.cookie) {
      FibsCookie.FIBS_ResumeMatchAck0 ||
      FibsCookie.FIBS_ResumeMatchAck5 => cm.crumbOrNull(FibsCrumbKeys.opponent),
      FibsCookie.FIBS_ResumeMatchRequest => cm.crumbOrNull(FibsCrumbKeys.name),
      _ => null,
    };
    return clearDelayForOpponent(opponent);
  }

  FibsResumeCoordinator clearAttemptForCookie(CookieMessage cm) {
    if (cm.cookie == FibsCookie.FIBS_Board ||
        cm.cookie == FibsCookie.FIBS_NoSavedGames) {
      return _clearPendingAttempt();
    }
    final opponent = switch (cm.cookie) {
      FibsCookie.FIBS_ResumeMatchAck0 ||
      FibsCookie.FIBS_ResumeMatchAck5 => cm.crumbOrNull(FibsCrumbKeys.opponent),
      _ => null,
    };
    if (opponent == null) return this;
    return pendingFor(opponent) ? _clearPendingAttempt() : this;
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

  FibsResumeCoordinator _clearPendingAttempt() => _copyWith(
    pendingOpponent: null,
    mode: mode == FibsResumeMode.attempting ? FibsResumeMode.idle : mode,
  );

  FibsResumeCoordinator _copyWith({
    Map<String, ResumeDelayInfo>? delays,
    Set<String>? parkedKeys,
    Object? pendingOpponent = _pendingOpponentUnchanged,
    FibsResumeMode? mode,
  }) => FibsResumeCoordinator._(
    delays: delays ?? _delays,
    parkedKeys: parkedKeys ?? _parkedKeys,
    pendingOpponent: identical(pendingOpponent, _pendingOpponentUnchanged)
        ? _pendingOpponent
        : pendingOpponent as String?,
    mode: mode ?? this.mode,
  );
}
