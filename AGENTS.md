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
- Analyze/lint: `flutter analyze` (lint config in `analysis_options.yaml`, based on `all_lint_rules_community` with many explicit overrides). CI (`.github/workflows/ci.yml`) gates on `dart format --set-exit-if-changed lib test`, `dart analyze --fatal-infos lib test`, and `flutter test` on every push/PR; Dependabot scans pub deps. CI currently analyzes only `lib`/`test`; the `packages/` workspace members are first-party code we own outright (there is no upstream — see below), so leaving them out of the strict gate is a known gap to close, not a principled exemption.
- Secure storage (`flutter_secure_storage`) backs remembered passwords on all platforms; **Linux** also needs `libsecret-1-dev` at build/run time.
- Test: `flutter test` — the suite covers the rules engine and game-model features (move generation, forced moves, doubling, stats, race/auto-bear-off, win-probability, piece-animation planning). `test/board_builder.dart` builds boards from a concise `{pipNo: signedCount}` spec for **partial** positions (most rule tests); `test/scenario_test.dart` uses `fibsboard`'s ASCII `boardFromLines` for **full-board** scenarios (which require a complete 15-checker-per-side position).

## Monorepo workspace

**We own 100% of the code in this repo.** Every file here — including all
`packages/` workspace members — is first-party source we author and are free to
refactor without consequence. There is **no external upstream and nothing to
"sync" to**: nothing here is a mirror or a vendored copy of another project. The
packages simply live in-repo so the checkout builds standalone. (The one genuine
*external* dependency is `backgammon_ai`, pulled as a git dep in
`pubspec.yaml` — its source is **not** in this folder; it lives in its own repo.
Everything under this folder is ours.)

This repo is a self-contained **Dart pub workspace** — it builds standalone with no sibling repos. The root `pubspec.yaml` lists `workspace:` members:

- `packages/bg_engine/` — the **pure-Dart backgammon engine**: rules + move generation (`GammonRules`, `GammonMove`, `GammonPlayer`, `GammonDelta`, `DoublingCube`, `CubeAction`), the `pubeval` evaluator, and the exact `RaceEval` race solver — all extracted out of `lib/model.dart`. No Flutter dependency (uses `package:meta`/`package:collection` for `@immutable`/list-equality). The app's `lib/model.dart` keeps `GammonState`/`GammonStats` (the `ChangeNotifier` UI state) and **re-exports** `package:bg_engine/bg_engine.dart`, so existing `import 'model.dart'` callers see the rule types unchanged. The pluggable AI-player abstraction (`BgAiPlayer`) and its implementations live here too. See `specs/architecture/game-modes-and-ai-players.md`.
- `packages/fibscli_lib/` — FIBS protocol/networking (CLIP cookies, `FibsConnection`, websocket proxy). Used only by the FIBS UI (`lib/fibs_state.dart`).
- `packages/fibsboard/` (dev dep) — board-from-ASCII helpers (`boardFromLines`/`linesFromBoard`) used by the full-board scenario tests.

Each member has its own minimal `pubspec.yaml` (with `resolution: workspace`) and keeps its **own** strict `analysis_options.yaml` — every package is an equal peer under the same lint rules. `flutter pub get` at the root resolves the whole workspace; there is a single root `pubspec.lock` and a single `.dart_tool/`. `packages/fibscli_lib` currently carries two `discarded_futures` infos — these are **ours to fix**, not an upstream artifact to be preserved; they're simply not cleaned up yet.

## FIBS networking is live in the UI

`lib/main.dart`'s `LandingPage` offers three paths: **Local 2-player**
(`GamePlayPage`, hot-seat), **Play vs Computer** (an AI picker over
`AiRegistry.available` → `GamePlayPage` with an `aiSide`/`BgAiPlayer`, driven by
`lib/local_ai_driver.dart`'s `positionFromState`/`playAiTurn`), and **Play a bot
(FIBS)** (`FibsPage`). The AI abstraction (`BgAiPlayer`, `PubevalAiPlayer`,
`AiRegistry`) lives in `packages/bg_engine`; see the spec. Three engines are
registered: the built-in `PubevalAiPlayer`, the bundled **`backgammon_ai`**
engine (a git dependency on `github.com/csells/backgammon_ai`, adapted to
`BgAiPlayer` in `lib/backgammon_ai_player.dart`), and a **gnubg-service**
adapter (`GnubgAiPlayer` + `HttpGnubgClient` in `bg_engine`; registered once a
service URL is configured). `lib/fibs_page.dart` is the working FIBS client UI —
login (with optional autologin from `--dart-define` `fibs_uname`/`fibs_pword`),
the live bot list (invite / watch), tap-to-move play, **"Play for me"**
(starts the autonomous `FibsBotPlayer`), resume of saved matches, and the
doubling cube. It drives `lib/fibs_state.dart` (`FibsState`, default
`localhost:8080`) over a [websocat](https://github.com/vi/websocat)
websocket→telnet proxy (see README). Move generation lives in
`lib/fibs_play.dart`: `bestTurnCommand` (pubeval) and `bestTurnCommandWithAi`
(any `BgAiPlayer`) both standardize on `bg_engine`'s shared `enumerateLegalTurns`
+ canonical board — the FIBS protocol parse/mirror is the only FIBS-specific
conversion. Autonomous bot play is `lib/fibs_bot_player.dart` (a policy layer
over `FibsState`, unit-tested offline + driven live by the gated e2e).

Remembered credentials use `lib/credential_store.dart`: the username lives in
`SharedPreferences`, the password ONLY in platform secure storage
(`flutter_secure_storage`, via the `SecretStore` adapter — Keychain / Keystore
/ libsecret / Credential Manager / Web Crypto). `bootstrap()` in `main.dart`
loads prefs + creds before any UI builds (tolerating a secure-storage failure so
a locked keychain degrades to the login screen instead of crashing); tests
inject their own `App.creds`. `main()` installs **global error handlers**
(`runZonedGuarded` + `FlutterError.onError`) that route every uncaught error to
the log. `FibsState` does **not** depend on credentials or `main.dart` (no import
cycle): explicit logout runs an injected `onLogout` hook (wired in `bootstrap` to
`App.creds.forget`) and tears the connection down (cancel subscription +
`close`); its cookie stream has an `onError`. Bot detection lives in
`lib/bot_policy.dart` (`BotPolicy`, pure). Logging goes through `package:logging`
(`setupLogging` in `lib/logging.dart`); cookie tracing logs only the cookie
**type**, never crumbs/raw, so other users' PII (who-list emails, chat) never
reaches the log.

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
  (`test/fibs_replay_test.dart`) re-checks generated moves against a captured
  trace fixture (`test/fixtures/game_trace_sample.txt`) with no server at all.
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

### The live tests (committed, but not run by default)

These hit the real server, so they're **gated** — a normal `flutter test` skips
them and never connects. Run them deliberately, with the websocat proxy up and
credentials in `.env` (`fibs_uname` / `fibs_pword`, never logged/committed):

```sh
websocat --binary ws-l:127.0.0.1:8080 tcp:fibs.com:4321 --exit-on-eof &
```

- **`test/fibs_live_e2e_test.dart`** — drives the app's own `FibsState`
  **event-driven (no polling)** with human-paced delays: resumes saved matches
  first, plays weak bots, wins a couple, logs out cleanly, and backs off if it
  can't get a game. Tagged `live` and gated behind `FIBS_LIVE=1` (see
  `dart_test.yaml`):

  ```sh
  FIBS_LIVE=1 flutter test --tags live
  ```

- **`tool/browser_e2e/`** — Playwright browser e2e of the served web build:
  landing → autologin (creds via `--dart-define`, never typed) → live bot list
  → logout. Run `./tool/browser_e2e/run.sh` (it builds, serves, and drives in
  one pass). See its README.

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

## Specs

Design docs live under `specs/`. **`specs/architecture/` files must NOT be numbered** — name them by topic (e.g. `game-modes-and-ai-players.md`), and give the doc a plain `# Title` heading with no numeric prefix. Numbered/sequential filenames are only for `specs/plans/`.
