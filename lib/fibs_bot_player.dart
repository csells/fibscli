import 'dart:async';
import 'dart:math';

import 'package:fibscli_lib/fibscli_lib.dart';

import 'fibs_play.dart';
import 'fibs_state.dart';

/// The outcome of a [FibsBotPlayer.run].
class BotPlayResult {
  const BotPlayResult({
    required this.wins,
    required this.losses,
    required this.invites,
    required this.why,
  });
  final int wins;
  final int losses;
  final int invites;
  final String why; // why the session ended (target reached, deadline, ...)
}

/// Plays FIBS matches against weak bots autonomously: resume any saved match
/// first, then invite a weak bot, play it out human-paced, and stop once we've
/// won enough (or hit a guard rail).
///
/// This is pure *policy* layered on a [FibsState] — it only ever calls the
/// state's existing primitives (`canRoll`/`canMoveNow`/`playFirstLegalMove`,
/// `availableBots`/`savedMatches`/`invite`/`resumeSavedMatch`/`joinGame`/...).
/// It is fully EVENT-DRIVEN (reacts to FIBS cookies; the only timers are the
/// human "think" pause and timeouts), and a single coalesced action per event
/// — combined with FibsState's throwing guards — means it can't double-send.
///
/// All durations are injectable so it can be unit-tested offline with a fake
/// transport; in production the defaults give human-ish pacing and gentle
/// FIBS-citizen guard rails (finish matches, back off when throttled).
class FibsBotPlayer {
  FibsBotPlayer(
    this._fibs, {
    Future<void> Function()? pace,
    void Function(CookieMessage cm)? onCookie,
    this.targetWins = 2,
    this.maxInvites = 10,
    this.botPrefix = 'BlunderBot',
    this.betweenMatchesPause = const Duration(seconds: 2),
    this.stallTimeout = const Duration(seconds: 90),
    this.deadline = const Duration(minutes: 25),
    this.noGameTimeout = const Duration(minutes: 6),
    this.inviteRetry = const Duration(seconds: 8),
    this.whoCooldown = const Duration(seconds: 12),
  }) : _pace = pace ?? _humanPause {
    _cookieObserver = onCookie == null ? null : (cm) => onCookie(cm);
    _fibs.cookieObserver = _cookieObserver;
    _fibs.addListener(_handleStateChanged);
  }

  final FibsState _fibs;
  final Future<void> Function() _pace;
  final int targetWins;
  final int maxInvites;
  final String botPrefix;
  final Duration betweenMatchesPause;
  final Duration stallTimeout;
  final Duration deadline;
  final Duration noGameTimeout;
  final Duration inviteRetry;
  final Duration whoCooldown;
  void Function(CookieMessage)? _cookieObserver;

  int wins = 0;
  int losses = 0;
  int invites = 0;

  final _done = Completer<BotPlayResult>();
  final _timers = <Timer>[];
  Timer? _stallTimer;
  var _matchOver = false;
  var _winnerIsMe = false;
  var _betweenMatches = false; // brief settle after a match ends
  var _burstDone = false; // the login who-list has finished arriving
  var _acting = false; // one paced action in flight (coalesces events)
  var _pendingInvite = false;
  var _seenMatchResultCount = 0;
  DateTime? _whoAt; // last `who` request, to rate-limit it

  static final _rng = Random();
  static Future<void> _humanPause() {
    final base = 800 + _rng.nextInt(1400);
    final extra = _rng.nextInt(12) == 0 ? 1500 + _rng.nextInt(2000) : 0;
    return Future<void>.delayed(Duration(milliseconds: base + extra));
  }

  /// Drive the session until the target wins are reached or a guard rail trips.
  /// Completes with the result; resigns any in-progress game on the way out.
  Future<BotPlayResult> run() {
    _burstDone = _fibs.whoListComplete;
    _fibs.refreshWhoList();
    _timers.add(Timer(deadline, () => _finish('deadline')));
    // stop sign: if we can't even get a game going, give up rather than sit on
    // a connection hammering `who` (e.g. the server is throttling us)
    _timers.add(
      Timer(noGameTimeout, () {
        if (wins + losses == 0 && !_inGame) {
          _finish('no game started — backing off the server');
        }
      }),
    );
    return _done.future;
  }

  /// Stop early (cancels timers, resigns any in-progress game, completes run).
  void stop([String why = 'stopped']) => _finish(why);

  void _finish(String why) {
    if (_done.isCompleted) return;
    _fibs.removeListener(_handleStateChanged);
    if (identical(_fibs.cookieObserver, _cookieObserver)) {
      _fibs.cookieObserver = null;
    }
    _stallTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    if (_inGame) _fibs.resign(); // leave nothing hanging
    _done.complete(
      BotPlayResult(wins: wins, losses: losses, invites: invites, why: why),
    );
  }

  bool get _inGame =>
      _fibs.gameState != null && _fibs.myColor != null && !_matchOver;
  bool get _hasGameAction =>
      _inGame &&
      (_fibs.doubleOffered ||
          _fibs.mustJoin ||
          _fibs.resumeRequestFrom != null ||
          _fibs.canRoll ||
          _fibs.canMoveNow);

  void _handleStateChanged() {
    if (_done.isCompleted) return;
    if (_consumeMatchResult()) return;
    if (_fibs.whoListComplete) {
      _burstDone = true; // safe to invite a fresh bot now
    }
    if (_inGame) {
      // A board during normal play means we're in a match. But FIBS can also
      // send a final board after a win/loss; the between-matches guard keeps us
      // from clearing matchOver on that one and firing a stray command.
      if (!_betweenMatches) _matchOver = false;
      _resetStall();
    }
    _scheduleAct();
  }

  bool _consumeMatchResult() {
    if (_fibs.protocolMatchResultCount == _seenMatchResultCount) return false;
    _seenMatchResultCount = _fibs.protocolMatchResultCount;
    final result = _fibs.lastProtocolMatchResult;
    if (result == null) return false;
    _matchOver = true;
    _winnerIsMe = result.didIWin;
    _onMatchOver();
    return true;
  }

  void _resetStall() {
    _stallTimer?.cancel();
    _stallTimer = Timer(stallTimeout, () {
      if (_inGame) _fibs.resign(); // the match-end event drives cleanup
    });
  }

  // coalesce a burst of events into one paced action, then re-check once (to
  // catch the roll->move follow-up). Lobby actions are re-triggered by their
  // own events/timers, so the game-action re-check can't busy-loop.
  void _scheduleAct() {
    if (_acting || _done.isCompleted) return;
    if (!_hasGameAction && _inGame) return; // opponent's turn -> wait
    if (!_inGame && (_pendingInvite || _betweenMatches)) return;
    _acting = true;
    unawaited(
      Future(() async {
        try {
          await _pace();
          if (!_done.isCompleted) _doOneAction();
        } finally {
          _acting = false;
        }
        if (_hasGameAction) _scheduleAct();
      }),
    );
  }

  void _doOneAction() {
    if (!_inGame) {
      _doLobby();
      return;
    }
    _pendingInvite = false;
    if (_fibs.doubleOffered) {
      _fibs.acceptDouble();
    } else if (_fibs.mustJoin || _fibs.resumeRequestFrom != null) {
      _fibs.joinGame(_fibs.resumeRequestFrom);
    } else if (_fibs.canRoll) {
      _fibs.roll();
    } else if (_fibs.canMoveNow) {
      // policy lives here (not in FibsState): pick the best complete turn, then
      // hand the pre-built command to the connection to send + commit.
      final board = _fibs.board;
      final cmd = board == null
          ? null
          : FibsPlay.bestTurnCommand(board, dice: _fibs.activeDice) ??
                FibsPlay.fullTurnCommand(board, dice: _fibs.activeDice);
      // null == a legitimate dance (dice but no legal move): send nothing and
      // let FIBS auto-pass.
      if (cmd != null) _fibs.commitTurnCommand(cmd);
    }
    _resetStall();
  }

  void _doLobby() {
    if (_betweenMatches || _pendingInvite || _done.isCompleted) return;
    // an opponent asking us to resume, or "type join" between games
    if (_fibs.resumeRequestFrom != null || _fibs.mustJoin) {
      _fibs.joinGame(_fibs.resumeRequestFrom);
      return;
    }
    // finish what we've started: always resume a saved match first
    if (_fibs.savedMatches.isNotEmpty) {
      _invite(_fibs.savedMatches.first, resume: true);
      return;
    }
    // wait for the login who-list to finish before inviting a fresh bot
    if (!_burstDone) return;
    if (invites >= maxInvites) {
      _finish('invite cap reached');
      return;
    }
    // ONLY weak bots: wildbg / MonteCarlo / GammonBot are 1800-2100+ and just
    // feed rated losses. If none is free, ask again and wait.
    final weak = _fibs.availableBots
        .map((b) => b.user)
        .where((u) => u.startsWith(botPrefix))
        .toList();
    if (weak.isEmpty) {
      _askWho();
      return;
    }
    _invite(weak.first, resume: false);
  }

  void _invite(String opponent, {required bool resume}) {
    if (resume) {
      _fibs.resumeSavedMatch(opponent);
    } else {
      _fibs.inviteBotByName(opponent, matchLength: 1);
    }
    invites++;
    _pendingInvite = true;
    // if the invite doesn't become a game in time, allow another attempt
    _timers.add(
      Timer(inviteRetry, () {
        _pendingInvite = false;
        if (!_inGame) _scheduleAct();
      }),
    );
  }

  void _askWho() {
    final now = DateTime.now();
    final age = _whoAt == null ? null : now.difference(_whoAt!);
    if (age == null || age > whoCooldown) {
      _fibs.refreshWhoList();
      _whoAt = now;
    }
  }

  void _onMatchOver() {
    _stallTimer?.cancel(); // the match is done; never resign into a dead game
    if (_winnerIsMe) {
      wins++;
    } else {
      losses++;
    }
    if (wins >= targetWins) {
      _finish('reached target wins');
      return;
    }
    // matchOver stays true (so _inGame is false even though the last board
    // lingers in FibsState) until the next match's first board clears it.
    _betweenMatches = true;
    _pendingInvite = false;
    _timers.add(
      Timer(betweenMatchesPause, () {
        _betweenMatches = false;
        _scheduleAct();
      }),
    );
  }
}
