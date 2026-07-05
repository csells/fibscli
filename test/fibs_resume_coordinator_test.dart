import 'package:fibscli/fibs_resume_coordinator.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login discovery parks the first unsolicited board once', () {
    final resume = FibsResumeCoordinator()..startLoginDiscovery();

    final first = resume.decideBoard(
      opponent: 'BlunderBot',
      hasSessionBoard: false,
    );

    expect(first.action, FibsResumeBoardAction.park);
    expect(first.opponent, 'BlunderBot');
    expect(first.refreshSavedGames, isTrue);

    final duplicate = resume.decideBoard(
      opponent: 'BlunderBot',
      hasSessionBoard: false,
    );

    expect(duplicate.action, FibsResumeBoardAction.ignore);
  });

  test('explicit resume admits the next board and tracks the attempt', () {
    final resume = FibsResumeCoordinator()..startLoginDiscovery();

    resume.beginAttempt('BlunderBot');

    expect(resume.pendingFor('BlunderBot'), isTrue);
    expect(
      resume.decideBoard(opponent: 'BlunderBot', hasSessionBoard: false).action,
      FibsResumeBoardAction.admit,
    );
  });

  test(
    'login-time resume acknowledgement parks instead of requesting board',
    () {
      final resume = FibsResumeCoordinator()..startLoginDiscovery();

      final decision = resume.acceptResumeAcknowledgement('BlunderBot');

      expect(decision.action, FibsResumeAckAction.park);
      expect(decision.opponent, 'BlunderBot');
      expect(decision.refreshSavedGames, isTrue);
      expect(resume.pendingFor('BlunderBot'), isFalse);
    },
  );

  test('pending resume acknowledgement requests a board', () {
    final resume = FibsResumeCoordinator()..beginAttempt('BlunderBot');

    final decision = resume.acceptResumeAcknowledgement('BlunderBot');

    expect(decision.action, FibsResumeAckAction.requestBoard);
    expect(decision.opponent, 'BlunderBot');
    expect(resume.pendingFor('BlunderBot'), isTrue);
  });

  test('resume delays clear pending attempts until they expire', () {
    final resume = FibsResumeCoordinator()..beginAttempt('BlunderBot');
    final delay = ResumeDelayInfo(
      opponent: 'BlunderBot',
      minutes: 5,
      receivedAt: DateTime.now(),
    );

    resume.recordDelay(delay);

    expect(resume.pendingFor('BlunderBot'), isFalse);
    expect(resume.delayFor('BlunderBot'), delay);
  });

  test('rejected resume replies clear pending attempts', () {
    final resume = FibsResumeCoordinator()..beginAttempt('BlunderBot');

    final cleared = resume.clearRejected(FibsCookie.FIBS_NoSavedMatch);

    expect(cleared, isTrue);
    expect(resume.pendingFor('BlunderBot'), isFalse);
  });

  test('delay messages parse only exact FIBS resume-delay text', () {
    final delay = FibsResumeCoordinator.parseDelay(
      'BlunderBot',
      'I will not attempt to resume for 5 minutes.',
    );

    expect(delay, isNotNull);
    expect(delay!.opponent, 'BlunderBot');
    expect(delay.minutes, 5);
    expect(
      FibsResumeCoordinator.parseDelay('BlunderBot', 'resume later'),
      isNull,
    );
  });
}
