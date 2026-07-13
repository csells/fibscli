# Gap Analysis: plans 001 + 002 — 2026-07-11

Fresh-eyes verification of every requirement in
`specs/plans/001-cloudflare-fibs-websocket-bridge.md` and
`specs/plans/002-cloudflare-hosting-and-web-analytics.md` against the current
implementation. Method: one evidence-gathering pass per requirement cluster,
then an independent skeptic pass that re-opened every cited file:line, re-ran
the package test suites, and re-issued the live `curl` checks. Statuses below
are post-skeptic.

## Plan 001 — Cloudflare FIBS WebSocket Bridge

| # | Requirement (spec §) | Status | Evidence |
|---|----------------------|--------|----------|
| A1 | Package with spec'd file tree (§4) | done | all files present; `src/bridge.ts` 20k substantive; 23/23 vitest |
| A2 | check/test/dev/deploy scripts (§4) | done | `package.json:6-11`, verbatim match |
| A3 | Not a pub workspace member (§4) | done | root `pubspec.yaml:6-9` lists only the three Dart packages |
| B1 | WS upgrade on `/` and `/fibs` (§5) | done | `config.ts:6`, `bridge.ts:169-214`; upgrade test uses `/fibs`; `/` shares the code path (live `/` → 426 confirms dispatch); a `/`-upgrade test variant would be nice-to-have |
| B2 | `/healthz` → 200 (§5) | done | `bridge.ts:155-163`; `request_test.ts:7` pins no-TCP; live 200 |
| B3 | non-WS bridge request → 426 (§5) | done | `bridge.ts:185-191`; live 426 on `/` and `/fibs` |
| B4 | unknown path → 404 (§5) | done | `bridge.ts:169-175`; test pins `/proxy?host=evil.test` → 404 without TCP; live 404 |
| B5 | Origin allowlist (§5) | done | `bridge.ts:193-199,663-673`; fail-closed on empty list; 403 `bad_origin` |
| C1 | pair/accept/connect fibs.com:4321 (§5) | done | `bridge.ts:209-214,483`; `config.ts:1-4` const target |
| C2 | text → UTF-8 bytes to TCP (§5) | done | `bridge.ts:580-582`; byte-equality test |
| C3 | binary → TCP unchanged (§5) | done | `bridge.ts:584-592`; test |
| C4 | TCP → browser binary frames (§5) | done | `bridge.ts:566-577`; test asserts Uint8Array frame |
| C5 | close/error propagation both ways (§5) | done | `bridge.ts:500-512,468`; tests both directions |
| C6 | no newline transformation (§5) | done | no `\n`/`\r`/replace on the data path; byte-for-byte tests |
| D1 | compile-time target, no request override (§6) | done | sole connect site uses `FIBS_TARGET`; only Upgrade/content-length/Origin read from requests |
| D2 | 8 KB max message, clear close (§6) | done | `limits.ts:1`; close 1009 `oversize` before TCP write; test |
| D3 | idle timeout (§6) | done | 10 min; armed pre-connect, re-armed on traffic; close 1001 |
| D4 | stricter pre-client-data timeout (§6) | done | 30 s; FIBS banner traffic does not extend it; test |
| D5 | clear close codes/reasons (§6) | done | 1000/1001/1009/1011 mapped to reason strings |
| E1 | metadata-only logging (§7) | done | all 10 log sites emit counts/categories/sanitized errors only |
| E2 | never logs frames/credentials/chat (§7) | done | exhaustive call-site audit; no payload reference |
| E3 | helper makes raw logging awkward (§7) | done (closed 2026-07-12) | `logging.ts` now types metadata as `LogValue = number \| boolean \| LogName` (closed category unions); a raw frame, chunk, or object payload is a **compile error** (`tsc`, gated in CI), proven by `log_typing_test.ts`'s `@ts-expect-error` guards and by a scratch payload-leak line failing `tsc` |
| E4 | tests pin credential absence (§7) | done | `logging_test.ts:7` drives real login + who-list, asserts absent from logs and metrics |
| F1 | AE binding + writes (§8) | done | `wrangler.toml:14-16`; 14 `emitMetric` sites |
| F2 | all 8 event types (§8) | done | every type located at a specific line |
| F3 | spec dimensions, no IP/UA (§8) | done | 12-blob schema matches; grep confirms no IP/user-agent |
| F4 | per-session aggregation, emit once on close (§8) | done | `SessionStats`; no per-frame emission; once-guard |
| F5 | docs/analytics.md with all starter queries (§8) | done | every spec-listed question has a query |
| F6 | analytics tests (§8) | done (closed 2026-07-12) | `metric_schema_test.ts` + `BLOB_COLUMNS`/`DOUBLE_COLUMNS`/`metricByType` decode each data point into named columns and assert exact slots for `session_reject` and `session_close`; a reordered schema now fails |
| G1 | default `wss://proxy.playfibs.com/fibs` (§9) | done | `fibs_state.dart:114-132` |
| G2 | withTransport/Factory kept for tests (§9) | done | defined + used across ~6 test files |
| G3 | FibsConnection path support + url test (§9) | done | `fibs_connection.dart:40-60`; `connection_url_test.dart:17-25` |
| G4 | no user proxy selection surface (§9) | done | only `fromEnvironment` seams; prefs audited |
| G5 | README: no bring-your-own-proxy (§9) | done | websocat framed as contributor-only |
| G6 | live tests gated, hosted endpoint (§11) | done | `dart_test.yaml` tag + `FIBS_LIVE=1`; defaults used |
| H1 | wrangler.toml compat date/AE/vars (§10) | done | all three present and consumed |
| H2 | deploy docs (§10) | done | package README:11-28 |
| H3 | CI runs worker checks (§10) | done | `ci.yml:21-29`; note: the repo's Dart CI job cannot clone the private git dependency without a credential (`GNUBG_SERVICE_TOKEN`) — unrelated to the worker job |
| H4 | manual deploy workflow w/ secrets (§10) | done | `deploy-fibs-proxy-worker.yml`; validates non-empty origins |
| H5 | live worker responds (§10) | done | healthz 200 / bogus 404 observed 2026-07-11 |

## Plan 002 — Cloudflare hosting + web analytics

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| I1 | site-worker tests pin redirect + assets passthrough | done | `site_test.ts`; 4/4 pass |
| I2 | handler is exactly redirect+fallthrough | done | 12-line `src/index.ts`; no scope creep |
| I3 | wrangler.jsonc per spec | done | assets/SPA/run_worker_first/domains/observability/compat date |
| I4 | tsc clean | done | `npm run check` exit 0 |
| I5 | live: apex 200, www 301 w/ path+query, SPA fallback 200 | done | observed 2026-07-11 |
| J1 | beacon in index.html + pinned test | done | `web/index.html:36`; token 32-hex; test green |
| J2 | privacy copy Cloudflare + Web Analytics, tested | done | `privacy_page.dart:69-78`; test pins no 'Firebase' |
| J3 | README documents wrangler site deploy | done | README:66-85 |
| J4 | live: exactly 1 beacon, token match, new privacy copy deployed | done | beacon count 1; tokens identical; bundle grep 1 |
| J5 | deferrals recorded in plan | done | plan lines 36-42 |

## Completion

- Plan 001: **100%** = 40 / 40 (was 97.5%; E3 and F6 closed 2026-07-12).
- Plan 002: **100%** = 10 / 10.

## Drift

None found.

## Outstanding items

None. E3 and F6 were closed on 2026-07-12 (see the table); the worker suite grew
from 23 to 28 tests and `dart analyze`/`tsc` both gate the invariants.

Dropped, deliberately: a `/`-path upgrade test variant (B1) — the code path is
shared with `/fibs` and live-verified, so a dedicated test adds near-zero
information.
