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

## Uncaught errors are surfaced on-device by default; remote reporting is opt-in

The Flutter and zone global error handlers route through `reportError`, which
logs via `package:logging`, posts a user-facing `AppError` to the `appErrors`
notifier (shown by the app root as a SnackBar whose **Details** action opens a
viewer over the retained `errorHistory`), and forwards to an optional
`errorSink`.

**Decision:** default to on-device observability — a transient SnackBar plus a
bounded, viewable error history — and make off-device reporting an explicit
opt-in (`bootstrap` installs an `httpErrorSink` only when
`--dart-define=crash_report_url=…` is set).

**Why:** the product target is a self-hosted client, so nothing should leave the
device unless a deployer chooses it; but "the user sees the error" is only useful
if the error outlives its SnackBar, hence the retained history + viewer.
`reportError` is the single seam and `errorSink` the single injection point, so
adding remote reporting required no call-site changes. The sink is
fire-and-forget and failure-swallowing: a crash reporter that can itself crash
the app is worse than none.

## The FIBS proxy target is hardcoded; users never choose a proxy

The bridge Worker connects only to the compile-time constant `fibs.com:4321`,
and the app exposes no UI control, URL parameter, or persisted setting for the
proxy endpoint — only `--dart-define` build seams for developers.

**Decision:** no user-facing proxy selection anywhere, and no request-supplied
target in the Worker, ever.

**Why:** backgammon players should open the app and play — hosting, choosing,
or pasting a proxy URL is infrastructure noise. A request-configurable target
would also turn the Worker into a generic TCP relay and an abuse vector.

## playfibs.com is hosted on Cloudflare Workers static assets, not Pages or Firebase

The release bundle is served by the `playfibs-site` Worker
(`packages/playfibs_site`) with SPA fallback and a www→apex redirect.

**Decision:** Workers static assets over Firebase Hosting (the previous host)
and over Cloudflare Pages.

**Why:** the `playfibs.com` zone already had to live on Cloudflare for the
proxy Worker's custom domain, so Firebase required maintaining cross-vendor
DNS verification records while everything else (DNS, proxy, analytics) was
Cloudflare-administered. Workers assets is Cloudflare's recommended path for
new static sites and reuses the exact deploy pattern, CLI, and CI secrets the
proxy Worker already established; Pages would have added a second deployment
model for no capability gain.

## The Web Analytics beacon is a static snippet, not Cloudflare auto-injection

`web/index.html` carries the deferred beacon with the playfibs.com site token.

**Decision:** static snippet in source, even though the dashboard-created
Web Analytics site has `auto_install: true`.

**Why:** Cloudflare's edge injection does not apply to Worker-served HTML
(verified empirically against the live site), so auto-install is inert here —
the static snippet is the only mechanism that actually measures. Keeping it in
source also makes the contract testable (`test/web_index_test.dart`) and the
served page verifiable (exactly one beacon after deploy, so no double-count if
Cloudflare's injection behavior ever changes).
