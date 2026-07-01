# Architecture Decisions

A single log of notable, non-obvious architectural decisions and the rationale
behind them. This is the one place where "why we chose X over Y" lives — source
comments describe the current implementation only, not the history that led to
it.

## The board is a typed `extension type`, but move generation stays on the raw list

The board is a `List<List<int>>` (26 points; signed piece IDs where the sign is
ownership and the magnitude is a stable per-checker id used for animation
tracking). `GammonBoard` (`packages/bg_engine/lib/src/board.dart`) is a Dart 3
`extension type` over that list, adding domain accessors (`ownerAt`, `countAt`,
`checkersAt`, `isVacantAt`).

**Decision:** type the board *entity* and its consumers with `GammonBoard`, but
leave the move-generation internals (`GammonRules.getAllLegalMoves` /
`applyMove` / …) operating on the raw list via indexing.

**Why:** `GammonBoard` `implements List<List<int>>` and erases to its
representation at runtime, so it is zero-cost and the engine already receives it
transparently wherever a `GammonState.board` is passed. Converting the hot inner
loops to the accessors would churn the most heavily-tested, highest-risk code in
the codebase for a readability gain the typed entity and its callers already
deliver.

## The FIBS crumb boundary is unpacked through a single typed accessor

FIBS cookies carry an untyped `Map<String, String>? crumbs`. Consumers unpack it
through `CookieMessage.crumb(key)` / `crumbOrNull(key)`, and the keys are named
once in `FibsCrumbKeys`.

**Decision:** access every crumb through `crumb`/`crumbOrNull` with a named key,
never `crumbs!['literal']!`.

**Why:** a required-but-absent crumb throws a `MissingCrumbError` naming the
cookie and key at the parse boundary, instead of a null-check crash at a distant
use site or a silently-empty value. The keys mirror the regex group names in
`fibscli_lib`'s cookie tables; if the two drift, `crumb` fails loudly.

## App-level dependencies are constructor-injected, not global statics

`bootstrap()` builds the `FibsState` and the credential store and returns them as
`AppDeps`; `main()` threads them into `App`, which hands them down
App → LandingPage → FibsPage → the views (`FibsState` also via the `FibsScope`
InheritedWidget).

**Decision:** no widget reaches a global for its `FibsState` or credential store;
both are injected. The only `App` static is `scaffoldMessengerKey` — a stable
`GlobalKey` the context-less global error handlers need.

**Why:** keeps the UI decoupled from mutable global state and lets tests supply
their own instances directly.

## Uncaught errors are surfaced to the user, not shipped off-device

The Flutter and zone global error handlers route through `reportError`, which
logs via `package:logging` and posts a user-facing `AppError` to the `appErrors`
notifier; the app root shows it as a SnackBar with a Copy action.

**Decision:** report uncaught errors to the user (with enough detail to retry or
copy into a report), not to a remote crash-reporting service.

**Why:** the product target is a self-hosted client; a remote sink is out of
scope. `reportError` is the single seam, so a remote reporter could later be
added by attaching another `Logger.root.onRecord` listener with no call-site
changes.
