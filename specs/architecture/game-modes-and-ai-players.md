# Game Modes and AI Players

How the app's four playable experiences hang together, and how any AI engine
plugs into all of them through one abstraction.

## The four modes

1. **Local 2-player** (hot seat) — `GamePlayPage` with no `aiSide`; both sides
   tap to move.
2. **Play Against the Computer** (1-player) — `GamePlayPage` with an `aiSide`
   and a `BgAiPlayer`, driven by `lib/local_ai_driver.dart`
   (`positionFromState` / `playAiTurn`).
3. **Play a bot on FIBS** — `FibsPage` / `FibsState` over the WebSocket bridge;
   the human plays.
4. **FIBS "Play for me"** — `lib/fibs_bot_player.dart` plays the human's side on
   FIBS, choosing moves through the same `BgAiPlayer` abstraction
   (`FibsPlay.bestTurnCommandWithAi`).

Modes 2 and 4 share every engine: an AI written once plays locally and on FIBS.

## The abstraction (`packages/bg_engine`, pure Dart)

`bg_engine` has **no Flutter dependency** and no HTTP dependency. That boundary
is load-bearing: anything needing Flutter or a network client lives in the app
layer instead.

- `BgPosition` — a representation-neutral snapshot (canonical engine board, the
  player on roll, dice, cube value/owner).
- `BgTurn` — the full chosen turn (a list of `GammonMove`s), so the engine owns
  sequencing and the driver just applies and commits. An empty list is a dance.
- `BgAiPlayer` — the engine contract: `prepare()` (warm anything costly at a
  natural pause), `chooseTurn()`, and optional `cubeDecision()` /
  `respondToDouble()` / `resignDecision()` that default to the shared
  `CubePolicy`, plus `name` / `description` / `dispose()`.
- `BgAiPlayerFactory` — builds players: `levels`, `levelLabel(level)`,
  `isLevelEnabled(level)` (a level this build cannot run is still listed, but
  shown disabled), and `create({level})`.
- `AiRegistry` — the registered factories the UI offers.

## The engines

**Harry Heuristic — level 0.** `PubevalAiPlayer`: enumerates every legal turn and
scores the resulting board with the ported `PubEval` evaluator. In-process,
offline, no configuration, available on every platform. Moves only (the shared
cube defaults apply).

**Gary Gammon — levels 1–7.** GNU Backgammon's calibrated leveled opponent,
novice → world-class, via the gnubg-service:

- `GnubgAiPlayer` (`bg_engine`) speaks the `GnubgClient` seam — the service's
  *play* surface (`playMove` / `playCube` / `playTake` / `playResign`), one
  decision per call, with the level and per-match seed fixed per opponent.
- It **never fabricates a decision**: the service's structured hops are applied
  to the position and matched by signature against a locally-enumerated legal
  turn (`positionSignature` / `matchTurnBySignature`), so the returned moves
  always have valid hops regardless of how gnubg collapses notation. If the
  service is unreachable, or its play matches no legal turn, it throws
  `GnubgUnavailableException` rather than passing a local heuristic off as
  gnubg's.
- `SessionGnubgClient` (`lib/`, **app layer** — it needs Flutter) implements the
  seam over the `gnubg_service` package's `GnubgSession`, which owns the
  generated OpenAPI client and the attested session-token lifecycle. The
  session/token contract (one app-scoped session, pre-warmed at the deal,
  permanent refusals never retried) is recorded in
  `specs/architecture/decisions.md`.

Both personas come from one registered factory, **`Computer`**
(`ComputerOpponentsFactory` in `lib/ai_engines.dart`), whose eight-step ladder is
the difficulty strip on the landing page. Gary is web-only and needs a
publishable key + Turnstile sitekey; without them levels 1–7 render disabled and
only Harry plays.

## Representations and adapters

`BgPosition` is the hub; each adapter is a pure, unit-tested function.

| Representation | Owner | Shape |
|---|---|---|
| Engine board (canonical) | `bg_engine` | length-26 `List<List<int>>`, signed piece ids |
| `GammonState` | app | the engine board + turn/dice/cube, as a `ChangeNotifier` |
| FIBS board | `fibscli_lib` | boardstyle-3 / `FibsBoard` |
| GNUBG position id | gnubg-service | `PositionID:MatchID` string over the wire |

- `GammonState → BgPosition` (`positionFromState`), and a chosen `BgTurn` back
  via `applyMove` + `commitTurn`.
- `FibsBoard ↔ BgPosition` (`lib/fibs_play.dart`), with chosen moves rendered as
  FIBS move commands.
- `BgPosition → GNUBG id` (`gnubgPositionId` / `gnubgMatchId`, exported from
  `bg_engine`): cube/take/resign encode a **pre-roll** match id (dice 0,0); the
  checker play encodes the dice in hand.

Harry needs no adapter — he reads the canonical board directly.

## Driving a turn

The 1-player game page calls `prepare()` at the deal (a remote engine warms its
credential there, so any human check lands in that pause instead of mid-turn),
then `playAiTurn` runs the AI's turn: cube decision, roll, moves (animated, with
human-paced delays), commit. An engine failure never strands the game on the AI's
turn — it surfaces with a Retry affordance, and the human is never asked to move
on the AI's behalf.

On FIBS, `FibsBotPlayer` is a policy layer over `FibsState` that asks the same
`BgAiPlayer` for each turn and issues the resulting FIBS commands.
