# iOS Failed History Retention, Delete, And Cleanup QA

Date: 2026-07-11
Milestone: P2 C4.2C-3 and final C4.2 retention, Delete, and audio-cleanup gate

## Scope

- Admit a sixth eligible failure only by selecting the deterministic absolute
  oldest failed row, moving that exact row into cleanup ownership, and adding
  the new pending-retirement row in one failed-root mutation.
- Make individual Delete commit only its selected ready row into one exact
  cleanup tombstone before any physical audio removal.
- Remove or confirm absence of at most one exact protected audio file, then
  retire only the tombstone authorized by the same source, outcome, root,
  owner, store pair, active lease, path, and byte-count evidence.
- Let ordinary lifecycle recovery process only the canonical cleanup head per
  call while allowing Delete to finish only its own receipt-bound tombstone,
  including when an older unrelated tombstone remains queued.
- Preserve exact cleanup state across source-visible and outcome-visible
  failed-journal uncertainty, transient protected-data failure, and relaunch,
  without another provider request, generic file removal, or unrelated
  failed-root mutation.
- Keep failed rows, cleanup tombstones, cleanup capabilities, protected audio,
  and coordinator state app-private and absent from the keyboard binary.

Policy-cutover integration, explicit Retry, public redacted containing-app
boundaries, and full lifecycle wiring remain C4.3 through C4.5. This checkpoint
adds no partial failed-History or Retry UI.

## Automated Evidence

- Focused strict suites:
  - failed-History cleanup Store: passed, 5 of 5 tests;
  - PendingRecording Store: passed, 47 of 47 tests;
  - protected-audio filesystem: passed, 42 of 42 tests;
  - failed-History cleanup coordinator: passed, 7 of 7 tests;
  - failed-History transfer coordinator: passed, 7 of 7 tests.
- `swift test --package-path Packages/HoldTypePersistence --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 749 tests in 37 suites.
- The matching strict-concurrency, warnings-as-errors release package build
  passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: passed, 441 tests, 0 failed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' test`
  - Result: passed, 1,112 tests, 0 failed, 0 skipped, on iPhone 16 Pro running
    iOS 18.6.
- The matching macOS and HoldType-iOS simulator build actions both passed.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: no failed-History or audio-cleanup value, capability, receipt,
    operation-state, store, or coordinator type entered the public graph.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: clean; no failed-History, cleanup, Persistence, protected-audio, or
    containing-app recovery linkage, symbol, or string entered the keyboard.
- `git diff --check`
  - Result: passed.

An initial fully concurrent full-package run saturated test-only timing windows.
Every affected suite passed in isolation before the serialized full gate, and
the canonical `--no-parallel` strict run then passed all 749 tests in 37 suites.
This was classified as runner scheduling saturation rather than a production
code failure; no product timeout was weakened for the closeout.

## Verified Retention And Delete Contract

- Stable failed-row ordering determines one absolute oldest candidate. An
  unsafe candidate or a full tombstone queue fails closed; retention never
  skips to a different row and never silently loses the incoming Pending work.
- Retention validates the full Failed/Pending protected namespace while holding
  both the eviction candidate and current Pending descriptors. The exact
  failed-root CAS simultaneously moves only that candidate into one tombstone
  and admits only the new pending-retirement row.
- Individual Delete validates the selected ready row and commits its logical
  row-to-tombstone transition before cleanup. That durable transition is the
  user-visible success boundary: later local cleanup trouble cannot resurrect
  the row or report the logical Delete as uncommitted.
- Delete uses two root-gate turns. The first releases the validated row
  descriptor and its old lease after the durable boundary; the second refreshes
  only the retained exact cleanup authority and never gains access to an older
  unrelated tombstone.
- Source-visible retention or Delete uncertainty requires a newly validated
  exact descriptor. Outcome-visible uncertainty confirms the intended journal
  bytes without reopening audio already under tombstone ownership.

## Verified One-Tombstone Cleanup Contract

- Ordinary lifecycle cleanup selects only the canonical tombstone head and
  returns after one file/tombstone pair. Explicit Delete may select only the
  tombstone minted from its exact logical-removal receipt and never loops into
  other queued cleanup work.
- The Pending store is the sole cleanup filesystem boundary. It seals the full
  protected namespace, revalidates the exact authorization and Pending metadata
  around the unlink, and returns either exact removal evidence or synchronized
  preexisting-absence evidence. Generic remove and publish paths are never used.
- Pre-unlink file identity, path, byte count, directory identity, root, stores,
  owner, and lease remain bound through the cleanup receipt. Interrupted system
  calls retry only where the POSIX contract permits it; an interrupted unlink
  is reconciled by exact post-call observation rather than blindly repeated.
- The failed store retires the tombstone only after validating that exact
  filesystem receipt. Source-visible journal uncertainty requires a fresh
  absence receipt; exact outcome-visible uncertainty is confirmed without a
  second filesystem cleanup.
- Failed-root mutation uncertainty and retained audio-cleanup ownership are
  independent interlock states. A revoked or foreign cleanup authorization
  cannot clear the retained cleanup block, and transfer/Delete cannot
  reinterpret that union block as their own mutation uncertainty.
- Fresh gate turns refresh the exact retained removal or retirement semantic
  phase. Completion uses a separate Store-minted capability, and only the exact
  completed state may clear the cleanup interlock.
- If journal retirement committed definitively but the following outcome read
  failed transiently, recovery completes the already-durable outcome first. It
  invokes CAS reconciliation only when the Store confirms actual retained
  mutation uncertainty, so it performs neither a second unlink nor a permanent
  same-process recovery wedge.
- After process loss, a still-present tombstone remains the sole durable cleanup
  authority. Already-absent audio is confirmed provider-free and the canonical
  tombstone retires without a generic deletion path.

## Independent Review Fixes

Independent P0/P1 reviews found and verified fixes for:

- pre-unlink identity handling that needed to keep the observed physical file
  bound through removal and reconcile `EINTR` without a blind second unlink;
- a revoked cleanup authorization that initially could still reach the Pending
  filesystem after abandon cleared its exact interlock; Pending now rechecks
  that retained binding before any journal or audio work;
- the two-gate Delete handoff, which needed fresh-lease authorization refresh
  plus a completion-only capability before clearing cleanup state and its
  interlock;
- an outcome-visible stale retirement phase that initially always entered CAS
  reconciliation. After a definitive commit followed by a transient completion
  read failure, that path had no retained mutation uncertainty and could wedge
  until process restart. Recovery now attempts exact durable completion first
  and reconciles only a confirmed uncertain mutation.

The final independent read-only review reported no remaining P0 or P1 finding
in C4.2.

## Gate Decision

P2 C4.2 deterministic retention, individual Delete, exact one-tombstone audio
cleanup, and tombstone retirement: passed for focused Store/filesystem/
coordinator suites, the serialized full strict package gate, release build,
macOS, iOS simulator, public API isolation, keyboard binary isolation, and
independent review.

C4.2 is complete. The next checkpoint is C4.3: join failed rows and retry-audio
ownership to the completed C3 History policy cutover without another policy
generation change.

This is not signed-device evidence. Effective Complete Data Protection while
locked, physical interruption behavior, and force-quit/process-eviction remain
their named device gates.
