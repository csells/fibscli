# Shared Agent Guide

This file is the canonical shared project instructions for Codex, Claude Code, and Gemini CLI. Keep project-wide guidance here; put tool-specific leftovers in `CLAUDE.md` or `GEMINI.md` only when they should not apply to the other agents.

## What this is

A Flutter app (`fibscli`) that is currently a standalone, single-player backgammon game. The long-term goal is an [FIBS](http://fibs.com) (First Internet Backgammon Server) web client, but FIBS networking is not wired into the live UI yet — see below.

## Commands

- Run (dev): `flutter run` (targets web/desktop/mobile; works across form factors)
- Build web: `./build-web.sh` → `flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true`
- Analyze/lint: `flutter analyze` (lint config in `analysis_options.yaml`, based on `all_lint_rules_community` with many explicit overrides)
- Test: `flutter test` — the suite covers the rules engine and game-model features (move generation, forced moves, doubling, stats, race/auto-bear-off, win-probability, piece-animation planning). `test/board_builder.dart` builds boards from a concise `{pipNo: signedCount}` spec for unit tests.

## Critical dependency caveat

`pubspec.yaml` declares two **path** dependencies on sibling repos that are NOT present in this checkout:

- `fibscli_lib: { path: ../fibscli_lib }` — FIBS protocol/networking (CLIP cookies, `FibsConnection`, websocket proxy)
- `fibsboard: { path: ../fibsboard }` (dev) — board-from-ASCII helpers used by the (commented-out) tests

`flutter pub get` will fail unless these repos are cloned as siblings. If they're missing, you can still read/edit code, but builds and `pub get` won't work.

## FIBS networking is stubbed out in the UI

`lib/main.dart` routes only to `GamePlayPage`; the login/who-list flow (`LoginPage`, `WhoPage`) is commented out in the `Navigator` pages list. `lib/fibs_state.dart` (`FibsState`, hardcoded to `localhost:8080`), `lib/login.dart`, and `lib/who_page.dart` exist but are not reachable in the running app. FIBS connectivity relies on a [websocat](https://github.com/vi/websocat) websocket→telnet proxy (see README) — this is future work, not current behavior.

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

**UI layer — `lib/game_play_page.dart`** is the main screen. `GameViewController extends ChangeNotifier` mediates between `GammonState` and the rendered board. Rendering is split into small widgets: `pieces.dart` (`PieceView` + `PieceLayout`), `pips.dart` (triangles/labels via `CustomPainter`), `dice.dart` (`DieView`/`DieState`), `pip_count.dart`, and `animated_layouts.dart` (`AnimatedPiece` tweens piece `PieceLayout`s between board positions). Layout objects (`PieceLayout`, `DieLayout`, etc.) carry geometry + highlight/edge flags computed from model state.

## Conventions (from analysis_options.yaml)

Prefer `final` over type annotations; single quotes; relative imports for local files (`always_use_package_imports: false`). `missing_required_param`, `missing_return`, and `parameter_assignments` are errors, not warnings.
