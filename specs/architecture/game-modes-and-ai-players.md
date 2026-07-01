# Game Modes & Pluggable AI Players

**Status:** Accepted (design); implementation in progress
**Date:** 2026-06-28
**Owner:** csells
**Supersedes:** n/a

## 1. Context

`fibscli` today has two reachable experiences from `LandingPage` (`lib/main.dart`):

1. **Local game** — `GamePlayPage` / `GameViewController`, a **2-player hot-seat**
   game where both sides tap to move. No AI is involved.
2. **Play a bot (FIBS)** — `FibsPage` / `FibsState`, a live FIBS web client that
   logs in over a websocat proxy and plays the server's bots. Move selection for
   the *autonomous* driver (`FibsBotPlayer`, used by the gated live e2e) is done
   by `lib/fibs_play.dart` scored by the ported `lib/pubeval.dart` evaluator —
   directly against the FIBS board, with no shared abstraction.

We want four first-class experiences and a single, pluggable AI abstraction that
can host multiple engine implementations (the built-in pubeval heuristic, the
`backgammon_ai` Dart engine, and the `gnubg-service` HTTP engine), with the user
choosing which AI to play against as that set grows.

This spec is the canonical design for: the game modes, the AI-player
abstraction, the package boundaries, the adapters between representations, and
how each mode drives a turn. It also records how the open
[architecture-scorecard](#9-folding-in-the-scorecard-fixes) findings are resolved
as part of the same effort.

## 2. Goals & non-goals

**Goals**
- Four modes: 2-player local, 1-player vs computer, 2-player vs FIBS bot, and
  FIBS "Play for Me" (the computer plays *your* side on FIBS).
- One async, representation-neutral AI abstraction (`BgAiPlayer`) that fits an
  in-process sync engine, an HTTP service, and the existing pubeval heuristic.
- A registry + picker so the user chooses which AI to play, extensible as new
  engines are added.
- Reuse the **same** pluggable AIs for local 1-player play and FIBS "Play for Me".
- Extract a reusable, pure engine so the AI is not coupled to the app's UI state.

**Non-goals (this round)**
- Live, authenticated `gnubg-service` wiring (keys, metering, network resilience)
  — the adapter is built and unit-tested against a fake; live wiring is a
  documented follow-on (§10).
- Networked human-vs-human play beyond FIBS.
- Rollouts / multi-ply tuning of the built-in heuristic.

## 3. The four modes

| Mode | Sides | Driver | Engine board | Status |
|------|-------|--------|--------------|--------|
| **2-player local** | Human vs Human (hot-seat) | UI taps | `GammonState` | Exists |
| **1-player vs computer** | Human vs `BgAiPlayer` | `GamePlayPage` drives the AI side | `GammonState` | New |
| **2-player FIBS bot** | Human vs FIBS bot | FIBS server | `FibsState` | Exists |
| **FIBS "Play for Me"** | `BgAiPlayer` plays your side vs FIBS bot | `FibsBotPlayer` → `BgAiPlayer` | `FibsState` | New (unify) |

The local 2-player game already exists and is unchanged. 1-player vs computer is
*the same board and rules* with an AI driving one side. The FIBS modes share the
live client; "Play for Me" routes the autonomous driver's move choice through the
chosen `BgAiPlayer` instead of calling pubeval directly.

## 4. The AI abstraction (`BgAiPlayer`)

Async, neutral, and full (checker play **and** cube/resign decisions, the latter
optional with conservative defaults). Async is required so an HTTP engine
(`gnubg-service`) fits the same contract; in-process engines complete the future
synchronously and may add a human-style "thinking" pace at the call site.

```dart
/// An immutable snapshot handed to an AI for one decision. Representation-neutral:
/// adapters convert to/from each engine's native form (§6).
class BgPosition {
  final List<List<int>> board; // canonical 26-cell signed-id engine board
  final GammonPlayer onRoll;
  final List<int> dice;        // available die values; doubles expanded to four
  final DoublingCube cube;
  const BgPosition({required this.board, required this.onRoll,
                    required this.dice, required this.cube});
  factory BgPosition.fromState(GammonState s) => ...;
}

/// A full chosen turn: the ordered checker moves to apply. Empty == dance.
class BgTurn { final List<GammonMove> moves; const BgTurn(this.moves); }

enum BgCubeAction { noDouble, offerDouble, take, pass }

/// The base class every AI engine implements.
abstract class BgAiPlayer {
  String get name;            // display name, e.g. 'Heuristic (pubeval)'
  String? get description => null;
  /// Optional difficulty levels this engine exposes (empty == single strength).
  List<String> get levels => const [];

  /// Choose the checker play for [p]. Returns an empty BgTurn for a dance.
  Future<BgTurn> chooseTurn(BgPosition p);

  /// Cube action when on roll, before rolling. Default: never double.
  Future<BgCubeAction> cubeDecision(BgPosition p) async => BgCubeAction.noDouble;
  /// Response to the opponent's double. Default: take.
  Future<BgCubeAction> respondToDouble(BgPosition p) async => BgCubeAction.take;

  void dispose() {}
}
```

**Why this shape**
- `chooseTurn` returns the **full turn** (a list of `GammonMove`), not one
  half-move, so the engine owns sequencing (forced moves, hit-on-the-way
  ordering) and the driver just applies + commits.
- Cube/resign are **optional** with safe defaults so the pubeval impl (moves
  only) needs no extra code, while richer engines (`backgammon_ai`, gnubg)
  override them.
- `BgPosition` carries the **canonical engine board** (the existing
  `List<List<int>>`), so the built-in impl needs no conversion; *non-native*
  engines convert at their own boundary (§6).

### Registry & selection

```dart
abstract class BgAiPlayerFactory {
  String get name;
  List<String> get levels;
  BgAiPlayer create({String? level});
}

class AiRegistry {
  static void register(BgAiPlayerFactory f);
  static List<BgAiPlayerFactory> get available;
}
```

- `bg_engine` registers **`PubevalAiPlayer`** out of the box, and
  **`GnubgAiPlayer`** when a service URL is configured.
- The app registers the **`backgammon_ai`** factory (it lives in the external
  package — §5).
- The picker UI lists `AiRegistry.available` (name + levels). 1-player and
  "Play for Me" both read from the same registry.

## 5. Package architecture

One new pure-Dart workspace package, plus a dependency on the external
`backgammon_ai` repo.

```
packages/bg_engine/                 (NEW — pure Dart, workspace member)
  rules + value types               GammonRules, GammonMove, GammonPlayer,
                                     GammonDelta(Kind), board helpers, RaceEval,
                                     pubeval scoring   (extracted from lib/model.dart)
  BgPosition, BgTurn, BgCubeAction   the neutral boundary types
  BgAiPlayer (abstract base)         the abstraction
  PubevalAiPlayer                    out-of-the-box heuristic impl
  GnubgAiPlayer + GnubgClient        HTTP adapter for gnubg-service (fake-tested)
  AiRegistry                         factory registry

fibscli (app)                        depends on bg_engine + backgammon_ai
  GammonState (ChangeNotifier)       stays in the app; uses bg_engine rules
  playAiTurn/positionFromState       drive + adapt a local AI side (UI: _maybePlayAi)
  FibsBotPlayer                      delegates move choice to a BgAiPlayer
  adapters                           GammonState<->BgPosition, FibsBoard<->BgPosition

~/Code/csells/backgammon_ai (external repo, path/git dep)
  depends on bg_engine               adds a dependency on the engine package
  BackgammonAiPlayer : BgAiPlayer    adapts BgPosition <-> its per-player Board
```

**Decisions**
- **Single `bg_engine` package** holds rules + value types + the `BgAiPlayer`
  abstraction + the pubeval impl + the gnubg adapter. (Per the owner's call:
  keep the abstraction and the out-of-the-box engine together; the gnubg adapter
  ships here too.)
- **`GammonState` stays in the app.** It is a `ChangeNotifier` (UI state
  management) — not engine logic. It depends on `bg_engine` for the rules.
- **`backgammon_ai` depends on `bg_engine`** and exposes its own `BgAiPlayer`
  impl, bundled into the app binary as a path/git dependency. (No vendoring.)
- `bg_engine` pulls **`package:http`** only for `GnubgAiPlayer`. If we later
  want a zero-dependency core, split `bg_engine_gnubg` out; not worth it now.

**Known wrinkle (follow-on, §10):** `bg_engine` lives in `fibscli/packages/`
but is depended on by the *external* `backgammon_ai` repo, i.e.
app → `backgammon_ai` → `../fibscli/packages/bg_engine`. That path dep works on
one machine but is fragile. Recommendation: once `bg_engine`'s API stabilizes,
promote it to its own repo (or publish it) and have both repos depend on that.

## 6. Representations & adapters

Four board representations exist; `BgPosition` is the hub.

| Representation | Owner | Shape |
|----------------|-------|-------|
| Engine board (canonical) | `bg_engine` | `List<List<int>>` length-26, signed piece ids |
| `GammonState` | app | wraps the engine board + turn/dice/cube |
| FIBS board | `fibscli_lib` | boardstyle-3 / `FibsBoard` |
| `backgammon_ai` `Board` | external | per-player pip-distance arrays + bar/off |
| GNUBG position id | gnubg-service | string id over the wire |

Adapters (each a pure function, unit-tested both directions where invertible):
- `GammonState → BgPosition` (`BgPosition.fromState`) and applying a `BgTurn`
  back via `GammonState.applyMove` + `commitTurn`.
- `FibsBoard ↔ BgPosition` (app) — converts the live FIBS board to the engine
  board and chosen `GammonMove`s back to FIBS move commands.
- `BgPosition → backgammon_ai Board` (external impl) — orientation/frame change.
- `BgPosition → GNUBG id` (`bg_engine`'s gnubg adapter).

The pubeval impl needs **no** adapter — it reads the canonical board directly.

## 7. Driving a turn

**Local 1-player** — the AI side is driven from the game UI by
`GamePlayPage`'s `_maybePlayAi`: when it becomes the computer's turn it builds a
`BgPosition` (via `positionFromState`), `await ai.chooseTurn(position)`, plays
each `GammonMove` **through the shared animated move path** (so the AI's moves
tween like the human's), then `commitTurn()`. Pacing delays are injectable
(`aiThinkDelay`/`aiMoveDelay`, zero in tests). The headless equivalent
`playAiTurn` (in `lib/local_ai_driver.dart`) backs the offline full-game test.
(An earlier standalone `LocalAiDriver` listener class was removed as redundant —
the UI loop owns the animation it cannot delegate.)

**FIBS "Play for Me" (`FibsBotPlayer` unified)** — the autonomous driver's move
selection delegates to a chosen `BgAiPlayer`: convert the live FIBS board to
`BgPosition`, `await ai.chooseTurn`, convert moves back to FIBS commands. Default
engine is pubeval (today's behavior), but the user may pick any registered AI.
The existing FIBS etiquette/throttling/state guards are unchanged.

## 8. UI / UX

`LandingPage` grows to offer the modes:
- **Local 2-player** → `GamePlayPage` (unchanged).
- **Play vs Computer** → AI picker (name + level from `AiRegistry`) → local game
  with the AI on the opponent side.
- **Play a bot (FIBS)** → `FibsPage` (unchanged).
- **FIBS Play for Me** → within `FibsPage`, a "Play for Me" control that starts/
  stops the unified `FibsBotPlayer` with the chosen AI.

The picker is a simple list of `AiRegistry.available`; engines with `levels`
show a difficulty sub-choice. pubeval is always present; `backgammon_ai` appears
when bundled; gnubg appears when a service URL is configured.

## 9. Folding in the scorecard fixes

The brutal-honesty audit's structural findings are resolved by this work and by
dedicated red-green TDD, targeting **≥85 on every principle**:

- **God object / coupling / import cycle** — extracting the rules into
  `bg_engine` and moving `GammonState` to depend on it removes the
  `fibs_state → main` reach for globals; credential handling is injected, not
  grabbed. `FibsState`'s bot-detection moves to a small policy type.
- **No global error handling** — `runZonedGuarded` + `FlutterError.onError` in
  `main`, `onError` on the FIBS stream subscription, and a `try/catch` around
  `bootstrap()` so secure-storage/prefs failures degrade to the login screen.
- **Resource leak** — `FibsState.logout()` closes the connection and cancels the
  stream subscription.
- **`// ignore:` suppressions** — removed by fixing the underlying issues (no
  blanket suppressions retained).
- **Test ratio** — new package + driver + adapter tests bring the ratio ≥0.5.
- **`FibsBotPlayer` had no app consumer** — now wired to the "Play for Me" UI.

## 10. Follow-ons (recommended, not in this round)

1. **Live gnubg wiring** — API keys, per-app tokens, metering, retry/backoff,
   and a real `GNUBG id` round-trip against the deployed Cloud Run service.
2. **Promote `bg_engine`** to its own repo or pub publish so `backgammon_ai`
   depends on a stable coordinate instead of a sibling path.
3. **Cube/resign for pubeval** — today defaults (never double / always take);
   could borrow the exact `RaceEval` cube logic for race positions.
4. **Difficulty tuning** for the built-in heuristic (ply, noise) to offer easy
   modes for human-vs-computer.

## 11. Sequencing

1. This spec. ✅
2. Scorecard fixes to ≥85 across the board (red-green TDD).
3. `bg_engine` package: extract rules, add `BgPosition`/`BgAiPlayer`/
   `PubevalAiPlayer`/`GnubgAiPlayer`/`AiRegistry` (TDD).
4. Modes UI + local AI driving + unify `FibsBotPlayer` + AI picker (TDD).
5. `backgammon_ai` adapter (cross-repo) + final brutal scorecard reassessment.
