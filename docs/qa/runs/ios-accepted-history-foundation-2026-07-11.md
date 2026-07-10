# iOS Accepted History Foundation QA

Date: 2026-07-11
Milestone: P2 accepted-History normal acceptance and relaunch recovery checkpoint

## Scope

- Bind the app-private History policy, accepted rows, outbox, delivery record,
  coordinator, capture, and opaque receipts to one root-scoped process owner.
- Persist an accepted-row decision only after durable delivery and two exact
  policy validations, then finish the delivery marker with proof of that exact
  decision.
- Preserve exact row, policy, marker, and expiry phases across local commit
  uncertainty without replaying provider work.
- Recover a preexisting delivery without inserting an absent row from caller
  data, and abandon expired bridge-revoked work through one sealed observation.
- Keep all History state and code outside App Group and the keyboard extension.

Pending-delivery transfer, the FIFO outbox worker, policy-cutover cleanup,
failed History, retry audio, Recording Cache, and UI remain later checkpoints.

## Automated Evidence

- `swift test --package-path Packages/HoldTypePersistence -Xswiftc
  -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 493 tests in 25 suites.
- The four stale-CAS coordinator cases passed 30 consecutive focused strict
  runs after the fake journal adopted nonblocking frozen snapshots.
- The accepted-History coordinator strict suite passed 10 consecutive focused
  runs.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: passed; no live provider or credential was used.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' test`
  - Result: passed, 856 tests in 105 suites on iPhone 16 Pro simulator, iOS
    18.6.
- `swift package dump-symbol-graph --minimum-access-level public`
  - Result: passed; raw accepted-row/outbox/policy stores, capability-owner
    identity, receipts, and delivery `accept`/`authorize` operations are not in
    the public module surface.
- `otool -L` and `nm -gU` on the simulator keyboard executable
  - Result: only the keyboard debug dylib and system loader are linked by the
    executable; no Domain, Persistence, OpenAI, IOSCore, accepted-History, or
    History symbols were found.
- `git diff --check`
  - Result: passed before checkpoint commit.

The iOS scheme runs this timing-sensitive Swift Testing bundle serially. The
previous parallel scheme made unrelated OpenAI timeout/cancellation tests miss
their short scheduler deadlines under full-suite load; both OpenAI suites
passed together when serialized, and the complete serialized suite then
passed. Product concurrency remains covered by explicit race tests and strict
concurrency compilation rather than wall-clock competition between all tests.

## Durability And Authority Evidence

- A public acceptance result exposes only the accepted delivery and one of four
  redacted History resolutions. Durable delivery is the provider-replay
  boundary; every later local failure returns pending recovery.
- Fresh acceptance and preexisting delivery provenance are distinct. Relaunch
  may confirm exact existing membership but cannot recreate an absent row.
- One FIFO, non-reentrant coordinator gate spans suspension. Cancellation before
  acquisition performs no transaction work; cancellation after acquisition
  cannot release partial work.
- Policy, delivery, row, outbox, baseline, expiry, and replacement capabilities
  all carry one opaque root owner. Foreign or mixed-owner inputs are rejected
  before clocks, journal reads, writes, or uncertainty probes.
- Exact row and marker phases survive commit uncertainty. A later call resumes
  the retained capability instead of reconstructing authority from IDs or text.
- Expiry first seals the exact observation, then confirms the same logical
  delivery revision and removes with store-bound authorization. Rollback after
  sealing cannot return the transaction to row or marker work.
- Deterministic frozen-snapshot tests exercise stale CAS without blocking the
  cooperative executor or relying on scheduler timing.

## Extension Isolation Evidence

- The `HoldTypeKeyboard` target still has no package dependencies.
- Accepted History paths, rows, receipts, delivery text, and capability-owner
  state are app-private and absent from the App Group and extension API.

## Independent Review

Read-only state-machine, capability-graph, API-surface, and security reviews
covered normal acceptance, replacement, expiry, supersession, rollback,
foreign capabilities, mixed-store assembly, and post-boundary recovery. The
final security review reported clean with no remaining P0 or P1 finding.

## Gate Decision

P2 accepted-History normal acceptance and provider-free relaunch recovery:
passed.

This is not physical-device evidence. Signed-device Complete Data Protection,
locked-device behavior, force-quit/process eviction, real App Group
projection/revocation, keyboard enablement, Full Access, and actual
`UITextDocumentProxy` insertion remain their named physical gates.
