# Integrate fibscli's gnubg opponent with the new `gnubg_service` Dart package

> Handoff prompt authored from the gnubg-service side (2026-07-12). Execute this in the
> fibscli repo. It is self-contained — you should not need to ask the gnubg-service agent
> anything to finish it.

## Mission
Replace fibscli's hand-rolled `HttpGnubgClient` (which targets gnubg-service endpoints
that **no longer exist** — it's broken against the live service today) with the new
`gnubg_service` Flutter package, adopting its generated OpenAPI client + managed
session-token flow, while leaving the tested `GnubgAiPlayer` adapter and the `GnubgClient`
seam untouched. Done = fibscli **web** plays a full game against the gnubg opponent through
the package, verified against a locally-run engine, with the whole workspace passing
`dart format`, `dart analyze --fatal-infos`, and `flutter test`.

## Boundaries
- **You own the fibscli repo** (`~/Code/csells/fibscli`) only.
- **Do NOT touch `~/Code/csells/gnubg-service`** — it's a separate repo/agent. You consume
  its `gnubg_service` package as a read-only git dependency. Never hand-edit the package's
  generated code (`packages/gnubg_service/lib/src/generated/**`).
- **Keep `packages/bg_engine` pure Dart.** It has NO Flutter dependency (pubspec: only
  `collection` + `meta`) and must stay that way — the entire AI-rules engine depends on it
  being Flutter-free. The `gnubg_service` package **depends on Flutter** (it's a
  `ChangeNotifier` + a Turnstile widget), so the new client that uses it **cannot live in
  `bg_engine`** — it goes in the Flutter app layer (`lib/`). This is the central
  architectural constraint of this task.

## Why this is needed (intent, not just mechanics)
fibscli's current `HttpGnubgClient` POSTs to `/v1/eval`, `/v1/cube`, `/v1/resign`. Those
endpoints were **removed** from gnubg-service months ago (they now return 404). The live
API is GET-based (`/v1/analyze/*`, `/v1/play/*`) and — critically — publishable keys are
now protected by **attested session tokens**: a browser exchanges its `bg_pk_` key + a
Cloudflare Turnstile challenge for a short-lived `bg_tk_` token at `POST /v1/token`, and
every data call runs under that token. The `gnubg_service` package encapsulates all of
this (the generated client + the mint/refresh/retry lifecycle + the Turnstile widget), so
fibscli should delegate to it rather than re-implement a client that would be wrong again
the next time the API changes.

The design that preserves fibscli's value: **keep the `GnubgClient` abstract seam and the
`GnubgAiPlayer` adapter exactly as they are** (the adapter's hops→legal-turn matching and
its never-fabricate-a-move discipline are tested and correct), and swap only the concrete
HTTP implementation for one backed by the package's `GnubgSession`.

## Files to read first (in order, with why)
1. `~/Code/csells/gnubg-service/packages/gnubg_service/README.md` — the package you're
   adopting: what `GnubgSession` does, the token flow, `turnstileAttest`, why the tokens
   endpoint exists. (Read the source too: `packages/gnubg_service/lib/src/session.dart` and
   `lib/src/turnstile_attestor.dart`.)
2. `packages/bg_engine/lib/src/ai/gnubg_ai_player.dart` — the `GnubgClient` abstract seam
   (line 155), the `Gnubg*` value types it returns, `GnubgAiPlayer` (the adapter — do NOT
   change its logic), and `GnubgAiPlayerFactory` (line 369, takes a `GnubgClient Function()`
   supplier, called per player at `create()`).
3. `packages/bg_engine/lib/src/ai/http_gnubg_client.dart` — the client you're replacing.
   Note the `_gnubgId(position, {preRoll})` static helper (line 97) — you'll move this logic
   into the new client; it uses `gnubgPositionId`/`gnubgMatchId` from `gnubg_id.dart`.
4. `packages/bg_engine/lib/bg_engine.dart` — the barrel. Line 8 exports
   `src/ai/http_gnubg_client.dart` (you'll delete that export). `src/ai/gnubg_id.dart` is
   **not** exported today — you'll need to add it (see work list).
5. `lib/ai_engines.dart` — `gnubgFactoryFor(serviceUrl, {apiKey})` builds the factory with
   an `HttpGnubgClient` supplier. This is where the wiring changes.
6. `lib/main.dart` around lines 125–133 (reads `--dart-define` `gnubg_service_url` /
   `gnubg_api_key`, registers the factory) and line 183 (`App.navigatorKey =
   GlobalKey<NavigatorState>()`, installed on `MaterialApp.router` at ~210, already used
   context-free at ~272). That navigator key is your Turnstile-dialog context source.
7. `AGENTS.md` — the standing rules and CI gates (below).

## The complete work list
1. **Add the git dependency** to the root `pubspec.yaml` (alongside `backgammon_ai`, which
   is the existing precedent for a git dep):
   ```yaml
   gnubg_service:
     git:
       url: https://github.com/csells/gnubg-service.git
       path: packages/gnubg_service
   ```
   Then `flutter pub get` at the repo root.

2. **Export the id builders** so the new client (in `lib/`) can reach them: add
   `export 'src/ai/gnubg_id.dart';` to `packages/bg_engine/lib/bg_engine.dart`.
   (`gnubgPositionId` and `gnubgMatchId` are already public top-level functions there;
   they're just not re-exported yet. `BgPosition` is already exported via `bg_ai_player.dart`.)

3. **Delete the dead client and its export and test:**
   - `packages/bg_engine/lib/src/ai/http_gnubg_client.dart`
   - the `export 'src/ai/http_gnubg_client.dart';` line in `bg_engine.dart`
   - `packages/bg_engine/test/http_gnubg_client_test.dart` (it asserts the removed
     `/v1/eval` paths — it's testing a contract that no longer exists).
   Keep `GnubgServiceError` if anything else references it — grep first; if only the deleted
   client used it, move it into the new client or drop it.

4. **Create the new session-backed client in the app layer** — e.g.
   `lib/session_gnubg_client.dart` — `class SessionGnubgClient implements GnubgClient`,
   constructed from a `GnubgSession`. Move the `_gnubgId(position, {preRoll})` logic from the
   old client into it (it's pure and still correct — cube/resign use `preRoll: true` = dice
   0,0; eval uses `preRoll: false`). Implement the three seam methods by calling the session
   and mapping the generated response types to `bg_engine`'s `Gnubg*` types (exact mapping
   below). `dispose()` calls `session.dispose()`.

5. **Rewire the factory** in `lib/ai_engines.dart`. `gnubgFactoryFor` now needs: the base URL
   (optional — the package defaults to `https://api.gammon.guru`), the **publishable key**,
   the **Turnstile sitekey**, and a way to get a live `BuildContext` for the attestation
   dialog. Build the supplier as:
   ```dart
   GnubgAiPlayerFactory(() => SessionGnubgClient(
     GnubgSession(
       baseUrl: serviceUrl.isEmpty ? null : serviceUrl,
       publishableKey: publishableKey,
       attest: () => turnstileAttest(
         App.navigatorKey.currentContext!, // app-lifetime context; always mounted
         siteKey: turnstileSiteKey,
       ),
     ),
     plies: 2,
   ))
   ```
   Use `App.navigatorKey.currentContext` (it already exists in `main.dart`) — the mint can
   happen mid-game, ~an hour after construction, so you must resolve a *live* context at mint
   time, never capture a stale widget context.

6. **Update the `--dart-define`s** in `main.dart` (and any run scripts / launch configs):
   - keep `gnubg_service_url` (now optional; empty ⇒ the package's default hosted URL)
   - replace `gnubg_api_key` with `gnubg_publishable_key` (a `bg_pk_…`)
   - add `gnubg_turnstile_sitekey`
   The gnubg opponent should still only register when a publishable key is configured (the
   "third engine appears when gnubg is available" behavior). Decide: offer it when the key is
   non-empty.

## Exact type mapping (generated response → bg_engine seam type)
The generated types come from `package:gnubg_service/gnubg_service.dart`. Field names are
verbatim from the generated Dart — match them exactly.

- `session.analyzeMove(id, plies: plies)` → `EvalResponse { List<RankedMove> moves }`.
  Map each `RankedMove` → `GnubgRankedMove`:
  - `RankedMove.play` (String) → `GnubgRankedMove.play`
  - `RankedMove.hops` (`List<MoveHop>`, each `MoveHop { int from; int to }`) → map to
    `List<GnubgHop>` (`GnubgHop { from, to }`)
  - `RankedMove.equity` (double) → `GnubgRankedMove.equity`
  - (`RankedMove.probabilities` has no seam equivalent — drop it.)
- `session.analyzeCube(id, plies: plies)` → `CubeResponse` → `GnubgCubeDecision`:
  - `CubeResponse.action` (`CubeAction`) → `GnubgCubeDecision.action` (`GnubgCubeAction`).
    Enum mapping (generated `CubeAction` members → seam `GnubgCubeAction`):
    `noDouble→noDouble`, `doubleTake→doubleTake`, `doublePass→doublePass`,
    `tooGoodToDouble→tooGoodToDouble`.
  - `CubeResponse.cubelessEquity` → `cubelessEquity`
  - `CubeResponse.cubefulNodouble` (note the lowercase **d**) → `GnubgCubeDecision.cubefulNoDouble`
  - `CubeResponse.cubefulDoubleTake` → `cubefulDoubleTake`
  - `CubeResponse.cubefulDoublePass` → `cubefulDoublePass`
- `session.analyzeResign(id, plies: plies, offered: offered)` → `ResignResponse` →
  `GnubgResignDecision`:
  - `ResignResponse.resignAdvice` (int 0..3) → `resignAdvice`
  - `ResignResponse.equityPlayOn` (double) → `equityPlayOn`
  - `ResignResponse.accept` (`bool?`) → `accept`

`GnubgSession` throws `ApiException` (re-exported from the package) on service errors; the
existing `GnubgAiPlayer._withRetry` catches `Exception`, so let `ApiException` propagate —
do not swallow it. The session already handles token expiry/budget re-mints internally, so
your client just calls the session methods and maps the results.

`GnubgSession` constructor (from the package, for reference):
`GnubgSession({ required String publishableKey, required Future<String> Function() attest,
String? baseUrl, http.Client? httpClient, DateTime Function()? clock, Duration
requestTimeout })`. `turnstileAttest(BuildContext context, { required String siteKey,
Duration grace, Duration timeout })` runs the challenge hidden and only shows a dialog when
Cloudflare demands interaction.

## Testing — the real artifact, against a LOCAL engine
The production hosted key won't authorize fibscli (its origin isn't allow-listed on any
key, and the Turnstile widget's domains would need fibscli's hostname — both are
**gnubg-service-side config you cannot change from this repo**; see "Cross-repo dependency"
below). So test against a **local engine** you run in Docker, exactly as the package's
example does, but on fibscli's pinned web port **9090** (AGENTS.md: "Keep Flutter web pinned
to 9090 … for gnubg-service integration work"):

1. Build the engine image once (from the gnubg-service repo root):
   `docker build -t gnubg-service:dev -f docker/service.Dockerfile .`
2. Run it with a key allow-listing fibscli's dev origin and Cloudflare's **published
   always-pass TEST** Turnstile secret (this pairs with the TEST sitekey
   `1x00000000000000000000BB` you'll pass to the app):
   ```bash
   docker run -d --name fibscli-gnubg -p 8080:8080 \
     -e GNUBG_AUTH='[{"account_id":"fibscli","keys":[{"key":"bg_pk_fibscli_localhost","app_id":"fibscli","allowed_origins":["http://localhost:9090","http://127.0.0.1:9090"],"quota":1000000,"rate_limit_per_min":0}]}]' \
     -e TOKEN_SIGNING_KEY=fibscli-local-secret \
     -e TURNSTILE_SECRET=1x0000000000000000000000000000000AA \
     gnubg-service:dev
   ```
   Wait for `curl -s localhost:8080/readyz` → `ready`.
3. Run fibscli web on 9090 pointed at it:
   ```bash
   flutter run -d web-server --web-hostname 127.0.0.1 --web-port 9090 \
     --dart-define=gnubg_service_url=http://localhost:8080 \
     --dart-define=gnubg_publishable_key=bg_pk_fibscli_localhost \
     --dart-define=gnubg_turnstile_sitekey=1x00000000000000000000BB
   ```
4. Pick the gnubg opponent and play a full game. Confirm real moves/cube/resign decisions
   flow. In the browser Network tab you should see `POST /v1/token` (→ 200) once, then
   `GET /v1/analyze/*` calls carrying `Authorization: Bearer bg_tk_…`.

**Unit tests** (this is a TDD repo — write these red-green): test `SessionGnubgClient`'s
mapping by constructing a `GnubgSession` with an **injected `http.Client`** (a `MockClient`
that scripts `/v1/token` then `/v1/analyze/move|cube|resign`) and a stub `attest` returning
a fake token — no Turnstile, no context needed. Assert the built GNUBG id, that calls carry
the session token, and that each generated response maps to the right `Gnubg*` value.
The package's own `test/session_test.dart` is the exact pattern to copy (`MockClient` from
`package:http/testing.dart`, a path→responses map). Put fibscli's test under `test/` (the
new client is in `lib/`, so its test is in the app's `test/`, not `bg_engine`'s).

## Cross-repo dependency (state this in your final report; don't try to do it here)
For fibscli to authorize against the **production** engine, someone must, on the
gnubg-service side: (a) add fibscli's origins (`http://localhost:9090` for dev and
fibscli's production web origin — its Firebase hosting URL) to a `bg_pk_` key's
`allowed_origins` in `deploy/gnubg-service.yaml`, and (b) add fibscli's hostnames to the
production Turnstile widget's domains. Those are gnubg-service-repo tasks. Your job is the
integration + local verification; flag the production wiring as the remaining hand-off.

## Native / desktop boundary (important)
This is a **web** integration. The session-token flow relies on the browser's `Origin`
header and a browser-hosted Turnstile challenge; native Dart HTTP sends no `Origin`, so
`POST /v1/token` 403s on desktop/mobile. fibscli builds for desktop too, so **do not offer
the gnubg-via-session opponent on non-web platforms** — gate it on `kIsWeb` (or simply on
the key being configured, which in practice only happens for web builds). A native gnubg
path (backend proxy, or platform attestation) is out of scope. Note this boundary in your
report.

## Standing rules (from fibscli's AGENTS.md — binding)
- **Red-green TDD**: failing test first, then implementation. The gnubg client suite is the
  model.
- **Never fabricate a gnubg decision**: `GnubgAiPlayer` throws `GnubgUnavailableException`
  rather than substitute a local move when the service fails. Preserve that — your client
  just maps or throws; don't add fallbacks.
- **Don't hand-edit generated code** (the package's `lib/src/generated/**` is off-limits and
  in another repo anyway).
- The **whole workspace** is gated: CI runs `dart format --set-exit-if-changed .`,
  `dart analyze --fatal-infos .` (info-level lints fail the build — `all_lint_rules_community`
  is strict), and `flutter test`. Every `packages/` member and `lib`/`test` must pass.
- Match surrounding style; each package's `analysis_options.yaml` includes the repo-root
  config — don't add per-file ignores to dodge the strict gate.

## Acceptance criteria
1. `flutter pub get` at the repo root resolves cleanly with the new git dependency.
2. `dart format --set-exit-if-changed .` → no changes. `dart analyze --fatal-infos .` → no
   issues (whole workspace). `flutter test` → all green, including the new
   `SessionGnubgClient` mapping tests (which must fail first without the implementation).
3. `packages/bg_engine` still has **no Flutter dependency** (grep its pubspec — only
   `collection` + `meta`), and `bg_engine.dart` no longer exports `http_gnubg_client`.
4. **Real artifact**: with the local engine from "Testing" running, fibscli web on port
   9090 plays a full game against the gnubg opponent; the browser Network tab shows one
   `POST /v1/token` → 200 followed by `GET /v1/analyze/*` calls under `Bearer bg_tk_…`.
   Report exactly what you exercised.
5. Report the two hand-offs: the production origin/Turnstile-domain config owed by the
   gnubg-service repo, and the native/desktop boundary.
