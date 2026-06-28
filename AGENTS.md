# Shared Agent Guide

This file is the canonical shared project instructions for Codex, Claude Code, and Gemini CLI. Keep project-wide guidance here; put tool-specific leftovers in `CLAUDE.md` or `GEMINI.md` only when they should not apply to the other agents.

## What this is

A Flutter app (`fibscli`): a standalone single-player backgammon game **and** a
working [FIBS](http://fibs.com) (First Internet Backgammon Server) web client.
The local game and the live FIBS client (login, bot list, play vs bots over a
websocat proxy) are both reachable from the landing page — see below.

## Commands

- Run (dev): `flutter run` (targets web/desktop/mobile; works across form factors)
- Build web: `./build-web.sh` → `flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true`
- Analyze/lint: `flutter analyze` (lint config in `analysis_options.yaml`, based on `all_lint_rules_community` with many explicit overrides)
- Test: `flutter test` — the suite covers the rules engine and game-model features (move generation, forced moves, doubling, stats, race/auto-bear-off, win-probability, piece-animation planning). `test/board_builder.dart` builds boards from a concise `{pipNo: signedCount}` spec for **partial** positions (most rule tests); `test/scenario_test.dart` uses `fibsboard`'s ASCII `boardFromLines` for **full-board** scenarios (which require a complete 15-checker-per-side position).

## Monorepo workspace

This repo is a self-contained **Dart pub workspace** — it builds standalone with no sibling repos. The root `pubspec.yaml` lists `workspace:` members and the two former path-dependency siblings are vendored under `packages/`:

- `packages/fibscli_lib/` — FIBS protocol/networking (CLIP cookies, `FibsConnection`, websocket proxy). Used only by the dormant FIBS UI (`lib/fibs_state.dart`).
- `packages/fibsboard/` (dev dep) — board-from-ASCII helpers (`boardFromLines`/`linesFromBoard`) used by the full-board scenario tests.

Each member has its own minimal `pubspec.yaml` (with `resolution: workspace`) and keeps its **own** strict `analysis_options.yaml` — every package is an equal peer under the same lint rules. `flutter pub get` at the root resolves the whole workspace; there is a single root `pubspec.lock` and a single `.dart_tool/`. The vendored sources are copied verbatim, so `packages/fibscli_lib` carries two pre-existing `discarded_futures` infos from upstream that are intentionally left as-is.

## FIBS networking is live in the UI

`lib/main.dart`'s `LandingPage` offers two paths: the standalone **Local game**
(`GamePlayPage`) and **Play a bot (FIBS)** (`FibsPage`). `lib/fibs_page.dart` is
the working FIBS client UI — login (with optional autologin from `--dart-define`
`fibs_uname`/`fibs_pword`), the live bot list (invite / watch), tap-to-move
play, resume of saved matches, and the doubling cube. It drives
`lib/fibs_state.dart` (`FibsState`, default `localhost:8080`) over a
[websocat](https://github.com/vi/websocat) websocket→telnet proxy (see README).
Move generation lives in `lib/fibs_play.dart`, scored by the ported
`lib/pubeval.dart` evaluator. The older `lib/login.dart` / `lib/who_page.dart`
are superseded by `FibsPage` and dormant.

## FIBS testing etiquette (be a gentle citizen)

Live testing hits the **real, shared** FIBS server. Be gentle — these are not
suggestions:

- **One connection per session.** Log in once, do everything you need on that
  single connection, log out once. Never run back-to-back login/logout cycles.
  FIBS throttles abusive reconnects (you'll see empty who-lists / missing
  pushes), and that throttling is a hard **stop sign** — stop immediately, don't
  push through it.
- **Iterate offline first.** Get the flow, coordinates, and parsing right
  against fakes or a captured trace before touching the live server, so a live
  run is **one clean pass**, not many. The widget tests inject a `FakeTransport`
  and `test/fibs_play_state_test.dart` scripts raw cookies; the offline replay
  (`tmp/replay_validate_test.dart`) re-checks generated moves against a captured
  `tmp/game_trace.txt` with no server at all.
- **Finish every match you start; never kill mid-game.** Resign + `leave`
  cleanly, or don't start it. A dropped connection orphans the opponent and
  saves the match. Resuming a saved match is supported
  (`FibsState.resumeSavedMatch` / `joinGame`) but it is *recovery*, not a
  workflow — don't rely on it to paper over abrupt exits.
- **Never spam commands.** `FibsState`'s `roll`/`move`/`offerDouble`/
  `acceptDouble`/`rejectDouble` throw `FibsStateError` when issued in the wrong
  state (rather than silently dropping), and `canRoll`/`canMoveNow` flip false
  the instant you act, so a correct driver can't double-send. Keep it that way.
- **Bots only; weak bots for rated play.** Only invite/accept from bots
  (detected by client string + a known-bot allowlist). For games meant to be
  won, stick to the weak **BlunderBot** family — wildbg / MonteCarlo / GammonBot
  are 1800-2100+ and just feed rated losses.

The live driver `tmp/play_game_test.dart` (gitignored) exercises this end to
end: it drives the app's own `FibsState` **event-driven (no polling)** with
human-paced delays, resumes saved matches first, plays weak bots, and logs out
cleanly. Run it via `flutter test tmp/play_game_test.dart` with the websocat
proxy up. Credentials live in `.env` (`fibs_uname` / `fibs_pword`) — never
logged, printed, or committed.

## Architecture

**Game model vs. FIBS model are separate.** The playable game (`GammonState`/`GammonRules` in `lib/model.dart`) is fully independent of the FIBS client code (`FibsState`). Don't conflate them.

**State management is a hand-rolled mini-framework** in `lib/tinystate.dart` — there is no `provider`/`riverpod`. Two primitives:
- `ChangeNotifierBuilder<T>` — an `AnimatedBuilder` that rebuilds on a `ChangeNotifier`.
- `NotifierList<T>` — a `List`-like `ChangeNotifier` that notifies on mutation.
App-wide singletons live as statics on `App` in `main.dart` (`App.fibs`, `App.prefs`).

**Core game engine — `lib/model.dart`:**
- `GammonState extends ChangeNotifier` — mutable game state (turn, dice, move number, undo snapshot via `_undoState`). The UI listens to this.
- `GammonRules` — a stateless namespace of `static` methods (no instances) implementing all backgammon rules: legal-move generation (`getAllLegalMoves`, `getLegalMoves`, `checkLegalMove`), application (`applyMove`, `applyDeltasForHop`), and bear-off/bar logic.
- **Board representation:** `List<List<int>>` of length 26. Index 0 = player1 off / player2 bar; indices 1–24 = points; index 25 = player1 bar / player2 home. Each inner list holds **signed piece IDs**: negative = player1, positive = player2 (sign encodes ownership, magnitude is a stable per-piece id used for animation tracking).
- `GammonPlayer { one, two }`, `GammonMove` (from/to pip + `hops` list of die-roll deltas; doubles produce up to 4 hops), `GammonDelta`/`GammonDeltaKind { move, hit, bar, bearoff }` describe the atomic effects of applying a move.
- `DoublingCube` (cube value/owner) and `GammonStats` (per-player rolls/pips/doubles) live alongside `GammonState`.

**Exact race solver — `lib/race_eval.dart`:** `RaceEval` solves no-contact (pure race) positions exactly via memoized expectimax over the 21 rolls — exact cubeless win probability plus a cubeful cube-ownership recursion for the double/take/pass decision (the `race2.c` algorithm from bkgm.com/rgb). `GammonState.winProbabilityFor` / `recommendedCubeAction` use it for races and fall back to `GammonRules.raceWinProbability` (a pip-count heuristic) only when contact remains.

**UI layer — `lib/game_play_page.dart`** is the main screen. `GameViewController extends ChangeNotifier` mediates between `GammonState` and the rendered board. Rendering is split into small widgets: `pieces.dart` (`PieceView` + `PieceLayout`), `pips.dart` (triangles/labels via `CustomPainter`), `dice.dart` (`DieView`/`DieState`), `pip_count.dart`, and `animated_layouts.dart` (`AnimatedPiece` tweens piece `PieceLayout`s between board positions). Layout objects (`PieceLayout`, `DieLayout`, etc.) carry geometry + highlight/edge flags computed from model state.

## Conventions (from analysis_options.yaml)

Prefer `final` over type annotations; single quotes; relative imports for local files (`always_use_package_imports: false`). `missing_required_param`, `missing_return`, and `parameter_assignments` are errors, not warnings.
