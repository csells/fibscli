// LIVE end-to-end test: drives FibsBotPlayer against the REAL FIBS server to
// resume any saved match, then play human-paced matches vs a weak bot and win a
// couple. The play *policy* lives in lib/fibs_bot_player.dart and is unit-tested
// offline (test/fibs_bot_player_test.dart); this test is just the thin live
// wrapper: log in, run the player, log out, assert we won.
//
// GATED so a normal `flutter test` never touches the live server: tagged `live`
// (see dart_test.yaml) and only runs when FIBS_LIVE=1. Run it explicitly with
// the websocat proxy up and credentials in .env:
//
//   websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof &
//   FIBS_LIVE=1 flutter test test/fibs_live_e2e_test.dart
//
// FIBS etiquette (see AGENTS.md): one login per run, weak BlunderBot bots only,
// finish every match, resume saved matches, log out cleanly, back off when
// throttled — all enforced by FibsBotPlayer.

@Tags(['live'])
library;

import 'dart:io';

import 'package:fibscli/fibs_bot_player.dart';
import 'package:fibscli/fibs_state.dart';
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

void main() {
  test(
    'resume saved matches, then win human-paced matches vs a weak bot',
    () async {
      final env = _env();
      final fibs = FibsState(proxy: '127.0.0.1');
      Directory('tmp').createSync(recursive: true); // trace output (gitignored)
      final trace = File('tmp/game_trace.txt').openWrite();

      await fibs.login(user: env['fibs_uname']!, pass: env['fibs_pword']!);
      expect(fibs.loggedIn, isTrue);

      final player = FibsBotPlayer(
        fibs,
        onCookie: (cm) {
          trace.writeln('${cm.cookie}  ${cm.crumbs ?? cm.raw}');
          if (cm.raw.startsWith('**') ||
              cm.raw.contains("can't") ||
              cm.raw.contains('not your')) {
            // ignore: avoid_print
            print('  <- NOTE ${cm.raw}');
          }
        },
      );
      final result = await player.run();
      // ignore: avoid_print
      print(
        'SESSION DONE — ${result.why} (wins=${result.wins} '
        'losses=${result.losses} invites=${result.invites})',
      );

      await fibs.logout();
      await trace.close();
      expect(result.wins, greaterThan(0), reason: 'should win at least once');
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip: Platform.environment['FIBS_LIVE'] == '1'
        ? null
        : 'live FIBS test — run with FIBS_LIVE=1 (needs .env creds + a '
              'websocat proxy on :8080); see AGENTS.md FIBS testing etiquette',
  );
}
