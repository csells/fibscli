import 'dart:math';

import 'package:bg_engine/bg_engine.dart';
import 'package:gnubg_service/gnubg_service.dart';

import 'session_gnubg_client.dart';

/// The app's single computer-opponent engine, **Computer**, exposing an
/// eight-step ladder:
///
/// - level 0 — **Harry Heuristic**: the offline [PubevalAiPlayer], playable
///   on every platform and build.
/// - levels 1–7 — **Gary Gammon**: the gnubg-service's calibrated leveled
///   opponent (novice → world-class) over an attested [GnubgSession], with a
///   fresh random per-match seed so the weakened tiers (1–4) play each match
///   their own way.
///
/// Every Gary shares ONE app-scoped session: a session token covers hundreds
/// of decisions, so re-minting (and any human check it carries) is an hourly
/// event rather than a per-game one. Disposing a finished game's opponent
/// therefore leaves the session open.
///
/// Gary needs a web build with a configured publishable key (the token mint
/// requires a browser Origin and a Turnstile challenge). Built without a
/// session supplier, the ladder still lists levels 1–7 — shown disabled by
/// pickers via [isLevelEnabled] — and [create] for them fails loudly rather
/// than silently substituting Harry.
class ComputerOpponentsFactory extends BgAiPlayerFactory {
  /// Creates the factory. [sessionFor], when non-null, builds a fresh
  /// [GnubgSession] per Gary player; null means Gary is unavailable in this
  /// build/platform.
  ComputerOpponentsFactory({required this.sessionFor});

  /// Builds the app's [GnubgSession] (once, lazily), or null when the online
  /// opponent is unavailable in this build/platform.
  final GnubgSession Function()? sessionFor;

  GnubgSession? _session;

  /// The service's calibrated tier names, indexed by level - 1.
  static const tierNames = [
    'novice',
    'beginner',
    'casual',
    'intermediate',
    'advanced',
    'expert',
    'world-class',
  ];

  static const _harryLabel = 'Harry Heuristic — ELO 1450 · offline';

  @override
  String get name => 'Computer';

  @override
  String? get description =>
      'Harry Heuristic offline, or Gary Gammon — GNU Backgammon '
      'calibrated from novice to world-class';

  @override
  List<String> get levels => [for (var n = 0; n <= 7; n++) '$n'];

  /// Whether the online Gary Gammon levels can actually be built.
  bool get garyAvailable => sessionFor != null;

  @override
  bool isLevelEnabled(String level) => level == '0' || garyAvailable;

  @override
  String levelLabel(String level) {
    final n = _levelNumber(level);
    return n == 0 ? _harryLabel : 'Gary Gammon — ${tierNames[n - 1]}';
  }

  @override
  BgAiPlayer create({String? level}) {
    final n = _levelNumber(level ?? '0');
    if (n == 0) {
      return PubevalAiPlayer(
        name: 'Harry Heuristic',
        description: 'ELO 1450 · offline',
      );
    }
    final buildSession = sessionFor;
    if (buildSession == null) {
      throw StateError(
        'Gary Gammon plays online only: this build has no gnubg-service '
        'key configured',
      );
    }
    return GnubgAiPlayer(
      SessionGnubgClient(
        _session ??= buildSession(),
        level: n,
        // A fresh seed per created opponent = per match: the weakened tiers
        // vary between matches but stay internally consistent within one.
        // 0x40000000 (2^30), not `1 << 32`: on the web ints are JS numbers,
        // where a 32-bit shift wraps to 0 and nextInt(0) throws.
        seed: Random().nextInt(0x40000000),
        // The session outlives this opponent: it is the app's, not the game's.
        ownsSession: false,
      ),
      name: 'Gary Gammon',
      description: tierNames[n - 1],
    );
  }

  // Parse [level] as one of this factory's ladder steps, or throw.
  static int _levelNumber(String level) {
    final n = int.tryParse(level);
    if (n == null || n < 0 || n > 7) {
      throw ArgumentError.value(level, 'level', 'must be 0..7');
    }
    return n;
  }
}
