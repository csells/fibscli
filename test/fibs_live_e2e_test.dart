// LIVE end-to-end test: drives the app's own FibsState against the REAL FIBS
// server to resume any saved match, then play human-paced 1-point matches vs a
// weak bot and win a couple. This is the live counterpart to the offline tests
// (fibs_play_state_test, fibs_replay_test, fibs_play_widget_test).
//
// It is GATED so a normal `flutter test` never touches the live server: it is
// tagged `live` (see dart_test.yaml) and only runs when FIBS_LIVE=1. Run it
// explicitly, with the websocat proxy up and credentials in .env:
//
//   websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof &
//   FIBS_LIVE=1 flutter test test/fibs_live_e2e_test.dart
//
// FIBS etiquette (see AGENTS.md): ONE login per run, event-driven (no polling),
// weak BlunderBot bots only, finish every match, resume saved matches, log out
// cleanly, and give up rather than hammer the server.

@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fibscli/fibs_state.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _env() {
  final m = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || !t.contains('=')) continue;
    final i = t.indexOf('=');
    m[t.substring(0, i).trim().toLowerCase()] = t
        .substring(i + 1)
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');
  }
  return m;
}

const _wantWins = 2;
const _maxInvites = 10; // hard backstop against invite spam

void main() {
  final rng = Random();
  Future<void> humanPause() {
    final base = 800 + rng.nextInt(1400);
    final extra = rng.nextInt(12) == 0 ? 1500 + rng.nextInt(2000) : 0;
    return Future<void>.delayed(Duration(milliseconds: base + extra));
  }

  test(
    'resume saved matches, then win human-paced 1-pointers vs a weak bot',
    () async {
      final env = _env();
      final fibs = FibsState(proxy: '127.0.0.1');
      Directory('tmp').createSync(recursive: true); // trace output (gitignored)
      final trace = File('tmp/game_trace.txt').openWrite();
      final done = Completer<void>();

      var wins = 0;
      var losses = 0;
      var invites = 0;
      var matchOver = false;
      var winnerIsMe = false;
      var betweenMatches = false; // brief settle after a match ends
      var lobbyReady =
          false; // wait out the login burst so saved games register
      var acting = false; // one paced action in flight (coalesces events)
      var pendingInvite = false; // an invite is outstanding
      Timer? stallTimer;
      final timers = <Timer>[]; // all pending timers, cancelled on finish
      DateTime? whoAt; // last time we asked for the who-list (rate-limit it)
      // forward declaration so earlier functions/timers can re-kick the scheduler
      late void Function() scheduleAct;

      void finish(String why) {
        if (done.isCompleted) return;
        // ignore: avoid_print
        print(
          'SESSION DONE — $why (wins=$wins losses=$losses invites=$invites)',
        );
        stallTimer?.cancel();
        for (final t in timers) {
          t.cancel(); // no lingering timers after the test body returns
        }
        done.complete();
      }

      bool inGame() =>
          fibs.gameState != null && fibs.myColor != null && !matchOver;
      bool hasGameAction() =>
          inGame() &&
          (fibs.doubleOffered ||
              fibs.mustJoin ||
              fibs.resumeRequestFrom != null ||
              fibs.canRoll ||
              fibs.canMoveNow);
      bool wantsAction() =>
          !done.isCompleted &&
          (hasGameAction() ||
              (lobbyReady && !inGame() && !pendingInvite && !betweenMatches));

      void resetStall() {
        stallTimer?.cancel();
        stallTimer = Timer(const Duration(seconds: 90), () {
          if (inGame()) {
            // ignore: avoid_print
            print('no progress 90s — resigning to free the bot');
            fibs.resign(); // the match-end event drives cleanup
          }
        });
      }

      void doLobby() {
        if (betweenMatches || pendingInvite || done.isCompleted) return;
        if (fibs.resumeRequestFrom != null || fibs.mustJoin) {
          fibs.joinGame();
          return;
        }
        if (invites >= _maxInvites) {
          finish('invite cap reached');
          return;
        }
        String? target;
        var resuming = false;
        if (fibs.savedMatches.isNotEmpty) {
          target = fibs.savedMatches.first;
          resuming = true;
        } else {
          // ONLY invite the weak BlunderBot family. wildbg / MonteCarlo /
          // GammonBot etc. are strong (1800-1900+) and would just feed rated
          // losses; if no BlunderBot is free, WAIT rather than fall back to one.
          final weak = fibs.availableBots
              .map((b) => b.user)
              .where((u) => u.startsWith('BlunderBot'))
              .toList();
          if (weak.isEmpty) {
            // ask for a fresh who-list, but at most every 12s so WHO_INFO events
            // can't trigger a `who` storm
            final now = DateTime.now();
            final age = whoAt == null ? null : now.difference(whoAt!);
            if (age == null || age > const Duration(seconds: 12)) {
              fibs.send('who'); // who-info events will bring us back here
              whoAt = now;
            }
            return;
          }
          target = weak.first;
        }
        // ignore: avoid_print
        print(
          resuming
              ? 'resuming saved match with $target'
              : 'inviting $target to a 1-point match',
        );
        if (resuming) {
          fibs.resumeSavedMatch(target);
        } else {
          fibs.send('invite $target 1');
        }
        invites++;
        pendingInvite = true;
        // if the invite doesn't become a game within 8s, allow another attempt
        timers.add(
          Timer(const Duration(seconds: 8), () {
            pendingInvite = false;
            if (!inGame()) scheduleAct();
          }),
        );
      }

      void doOneAction() {
        if (inGame()) {
          pendingInvite = false;
          if (fibs.doubleOffered) {
            fibs.acceptDouble();
          } else if (fibs.mustJoin || fibs.resumeRequestFrom != null) {
            fibs.joinGame();
          } else if (fibs.canRoll) {
            fibs.roll();
          } else if (fibs.canMoveNow) {
            final c = fibs.playFirstLegalMove(); // null == legitimate dance
            if (c != null) {
              // ignore: avoid_print
              print('move (${fibs.board!.activeDice.join(",")}): $c');
            }
          }
          resetStall();
        } else {
          doLobby();
        }
      }

      // event-driven scheduler: coalesce a burst of events into one paced action,
      // then re-check once (to catch the roll->move follow-up or an event that
      // landed during the human pause). NOT polling -- nothing re-runs unless an
      // event or a genuine follow-up needs it.
      scheduleAct = () {
        if (acting || !wantsAction()) return;
        acting = true;
        unawaited(
          Future(() async {
            try {
              await humanPause();
              if (!done.isCompleted) doOneAction();
            } finally {
              acting = false; // never let the scheduler wedge
            }
            if (hasGameAction()) scheduleAct();
          }),
        );
      };

      void onMatchOver() {
        stallTimer
            ?.cancel(); // the match is done; never resign into a dead game
        if (winnerIsMe) {
          wins++;
        } else {
          losses++;
        }
        // ignore: avoid_print
        print(
          'MATCH OVER — winner: ${winnerIsMe ? "me" : "opponent"}  '
          '(wins=$wins losses=$losses)',
        );
        if (wins >= _wantWins) {
          finish('reached target wins');
          return;
        }
        // matchOver stays true (so inGame() is false even though the last board
        // lingers in FibsState) until the NEXT match's first board clears it.
        betweenMatches = true;
        pendingInvite = false;
        timers.add(
          Timer(const Duration(seconds: 2), () {
            betweenMatches = false;
            scheduleAct(); // back to the lobby to start the next match
          }),
        );
      }

      fibs.cookieObserver = (cm) {
        trace.writeln('${cm.cookie}  ${cm.crumbs ?? cm.raw}');
        switch (cm.cookie) {
          case FibsCookie.FIBS_Board:
            // A board during normal play means we're in a match. But FIBS also
            // sends a FINAL board right after a win/loss; the `betweenMatches`
            // guard (set in onMatchOver for 2s) keeps us from clearing matchOver
            // on that one and firing a stray command ("you're not playing").
            if (!betweenMatches) matchOver = false;
            resetStall();
            scheduleAct();
          case FibsCookie.FIBS_YouRoll:
            resetStall();
            scheduleAct();
          case FibsCookie.FIBS_AcceptRejectDouble:
          case FibsCookie.FIBS_ResumeMatchRequest:
          case FibsCookie.FIBS_JoinNextGame:
          case FibsCookie.CLIP_WHO_INFO:
            scheduleAct();
          case FibsCookie.FIBS_YouWinMatch:
            matchOver = true;
            winnerIsMe = true;
            onMatchOver();
          case FibsCookie.FIBS_PlayerWinsMatch:
            matchOver = true;
            winnerIsMe = false;
            onMatchOver();
          // ignore: no_default_cases
          default:
            if (cm.raw.startsWith('**') ||
                cm.raw.contains("can't") ||
                cm.raw.contains('not your')) {
              // ignore: avoid_print
              print('  <- NOTE ${cm.raw}');
            }
        }
      };

      await fibs.login(user: env['fibs_uname']!, pass: env['fibs_pword']!);
      expect(fibs.loggedIn, isTrue);
      // ignore: avoid_print
      print('logged in as ${fibs.user}');

      // overall deadline + backstop if the event stream goes quiet
      timers.add(Timer(const Duration(minutes: 25), () => finish('deadline')));
      // stop sign: if we can't even get a game going, give up rather than sit on
      // a connection hammering `who` (e.g. the server is throttling us)
      timers.add(
        Timer(const Duration(minutes: 6), () {
          if (wins + losses == 0 && !inGame()) {
            finish('no game started in 6m — backing off the server');
          }
        }),
      );
      // kick the lobby once the initial who-list / saved-games have arrived
      timers.add(
        Timer(const Duration(seconds: 3), () {
          lobbyReady = true;
          scheduleAct();
        }),
      );

      await done.future;

      if (inGame()) fibs.resign(); // leave nothing hanging
      await Future<void>.delayed(const Duration(seconds: 2));
      await fibs.logout();
      await trace.close();
      expect(wins, greaterThan(0), reason: 'should win at least one match');
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip: Platform.environment['FIBS_LIVE'] == '1'
        ? null
        : 'live FIBS test — run with FIBS_LIVE=1 (needs .env creds + a '
              'websocat proxy on :8080); see AGENTS.md FIBS testing etiquette',
  );
}
