# iOS Failed History Pending Transfer QA

Date: 2026-07-11
Milestone: P2 C4.2B row-first PendingRecording ownership transfer

## Scope

- Capture and validate the exact awaiting-recovery Pending journal and its
  descriptor-backed protected audio before policy confirmation.
- Commit one failed row as `pendingJournalRetirement` before removing any
  Pending metadata, then remove only the exact physical Pending journal source.
- Prove the canonical Pending journal path durably absent before advancing only
  that failed row to `ready`, without changing its transfer timestamp.
- Resume row, unlink, and ready uncertainty under a fresh root-gate lease
  without a second row, provider request, audio read, or audio removal.
- Reconstruct provider-free relaunch authority only from the exact durable PJR
  row and distinguish terminal `ready` ownership from recreated Pending state.
- Prevent ordinary Pending load, provider, recovery, and discard paths from
  regaining authority after any failed row or tombstone owns the attempt or
  audio identifier.

Sealed namespace inventory, deterministic retention, Delete, and tombstone
audio cleanup remain C4.2C. Policy-cutover integration, explicit Retry, and the
public containing-app boundary remain C4.3 through C4.5.

## Automated Evidence

- `swift test --package-path Packages/HoldTypePersistence -Xswiftc
  -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 695 tests in 33 suites.
- Focused C4.2B suites passed for the happy row-first path, exact PJR relaunch,
  terminal Ready absence, recreated-Pending conflict, exact committed-source
  lease refresh, visible/invisible row and ready uncertainty, capacity,
  collision, and ordinary Pending load/discard interlocks.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test -quiet`
  - Result: passed, 441 tests, 0 failed, 0 skipped.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' test -quiet`
  - Result: passed, 1,058 tests, 0 failed, 0 skipped, on iPhone 16 Pro running
    iOS 18.6.
- The matching HoldType-iOS simulator `build` action passed and produced the
  containing app with its keyboard extension.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: failed-row values, journals, transfer sources, preparations,
    directives, receipts, operation state, store identities, root leases, and
    recovery inspection remain internal. No failed-transfer symbol or
    `FileHandle` entered the public graph.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: no Domain, Persistence, IOSCore, OpenAI, PendingRecording,
    accepted-History, failed-History, policy, or root-identity linkage or symbol
    is present.
- `git diff --check`
  - Result: passed.

## Verified Transfer Contract

- The Pending store first seals the complete physical journal snapshot and a
  validated descriptor. Missing or invalid audio therefore fails before policy
  confirmation or failed-journal bytes.
- The policy receipt, transfer timestamp, Pending and Failed store identities,
  canonical root, active lease, intended row, and audio metadata are frozen in
  one preparation. Retry never samples a new row or timestamp.
- A successful failed-row append makes the PJR row canonical before the audio
  descriptor is released. The next boundary removes metadata only; the exact
  audio inode and byte count remain unchanged through happy-path and relaunch
  reconciliation.
- `removed` receipts bind the exact observed Pending physical snapshot.
  `alreadyAbsent` receipts invent no source revision and require directory
  synchronization plus repeated canonical-path absence.
- A retained committed observation is reauthorized under a fresh lease without
  weakening its exact Pending source to relaunch matching. A semantically equal
  recreated journal therefore remains a conflict and is never deleted.
- Ready confirmation preserves every row field, including `updatedAt`, and
  advances only ownership plus the failed-root revision.
- Relaunch with PJR plus exact or absent Pending metadata completes without
  reading policy or invoking a provider. Ready plus absent Pending is terminal;
  Ready plus matching recreated Pending fails closed and preserves both
  journals and the audio.
- Public Pending replicas resolving one canonical physical root now use its one
  root-owned Pending store identity, matching the Failed store's bound expected
  owner. Foreign inspector/store wiring poisons coordinator composition.

## Independent Review Fixes

Read-only reviews found and verified fixes for:

- optional failed-owner inspection that initially allowed injected Pending
  stores to fail open;
- proofs that initially did not bind the exact Failed store identity or block
  an unrelated in-progress PJR row;
- a one-stage seal that confirmed policy before validating Pending audio;
- relaunch recovery that initially could not distinguish terminal Ready plus
  absence from Ready plus recreated Pending metadata;
- stale semantic state and descriptor release after a definitive row failure;
- fresh-lease observation refresh that initially weakened
  `.committed(exactSource)` to `.relaunched`, allowing deletion of a recreated
  semantically matching Pending journal;
- process-local transfer recovery that initially did not symmetrically exclude
  retained acceptance, replacement, outbox, delivery, or policy-cutover work,
  and reciprocal operations that did not yet block on transfer state or a
  durable PJR row after relaunch.

The final repeated P0/P1 review reported no remaining blocker in C4.2B.

## Verdict

P2 C4.2B row-first PendingRecording ownership transfer: passed for strict
package tests, macOS, iOS simulator, public API isolation, keyboard binary
isolation, durable relaunch recovery, ordinary Pending interlocks, and
independent review.

The next checkpoint is C4.2C: bounded sealed protected-audio inventory,
deterministic retention, individual Delete, and exact tombstone cleanup. No
partial failed-History or Retry UI ships from this checkpoint.
