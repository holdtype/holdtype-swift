# iOS Failed History Retry Reservation And Live Ownership QA

Date: 2026-07-11
Milestone: P2 C4.4A explicit Retry reservation and live ownership

## Scope

- Freeze one credential-eligible containing-app setup snapshot before any
  durable Retry write, including Transcription, optional Translation, and Keep
  Latest Result inputs.
- Reserve exactly one current-policy ready failed row, increment its retry
  count once, hold its already-validated audio descriptor, and commit
  `providerDispatched` before releasing the shared physical-root gate.
- Register one stable root-shared provider owner and start the one-shot provider
  task only after that gate turn has ended.
- Exclude a live PendingRecording provider and a live failed-row Retry in both
  directions.
- Cancel only the exact dispatched Retry on explicit cancellation, caller task
  cancellation, provider self-cancellation, handoff deinit, audio-transfer
  failure, or retained same-process recovery.
- Drain provider work and invalidate descriptor access before the failed row
  becomes retryable, while preserving exact cancellation authority through
  bounded transient failures.
- Reconcile reservation, dispatch, and cancellation commit uncertainty only as
  the same frozen operation, without minting another retry count, registration
  epoch, terminal epoch, or provider launch.

Provider outcome mapping, transient Translation, Usage recording, accepted
output, process-loss recovery, and public containing-app History surfaces
remain C4.4B through C4.5.

## Automated Evidence

- Focused reservation, audio, coordinator, and live-owner suites passed:
  36 tests in 4 suites.
- `swift test --package-path Packages/HoldTypePersistence --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 797 tests in 41 suites.
- The matching strict-concurrency, warnings-as-errors release package build
  passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test -quiet`
  - Result: 441 passed, 0 failed, 0 skipped.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' build`
  and the matching test action passed on iPhone 16 Pro running iOS 18.6.
  - Test result: 1,160 passed, 0 failed, 0 skipped.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: C4.4A setup, reservation, dispatch, live-owner, handoff, terminal
    claim, cancellation relay, and coordinator symbols remain absent from the
    public graph.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: only expected system linkage; no Domain, Persistence, IOSCore,
    OpenAI, PendingRecording, History, policy, or Retry linkage, symbol, or
    string entered the keyboard.
- `git diff --check`
  - Result: passed.

## Verified Reservation And Dispatch Contract

- Setup eligibility and intent compatibility are checked before the first
  durable Retry mutation. Setup and provider-completion diagnostics redact all
  configuration and result payloads.
- Reservation uses the current enabled policy receipt, exact row, exact compact
  Transcription configuration, and a validated descriptor proof. A tombstone
  slot is admitted before the row can protect future accepted output.
- `reserved` and `providerDispatched` are separate durable CAS boundaries. The
  same exact operation reconciles source- and outcome-visible uncertainty;
  initial `.completed` cannot authorize a fresh provider launch.
- The provider registration is installed and retained before descriptor
  transfer and before the root gate is released. Execution is one-shot, and
  the provider task cannot begin until the gate turn has ended.
- The provider receives only the existing bounded descriptor-backed audio
  interface. The source can be taken only by the matching dispatch and stable
  registration; unrelated, invalidated, or repeated takes fail closed.

## Verified Cancellation And Ownership Contract

- PendingRecording and failed Retry share one canonical physical-root provider
  exclusion boundary. Neither can publish or begin while the other owns live
  provider work.
- Completion and cancellation race through mutually exclusive exact terminal
  epochs. A cancellation claim is re-exposed only for its original stable
  registration and never reminted from IDs.
- Explicit cancellation, caller task cancellation, deinit, and provider
  self-cancellation use the same relay. Exact handoff identity prevents a
  provider task from receiving self-drain treatment for another handoff, while
  callback tasks have a nonblocking cancellation request.
- Audio access is invalidated before provider drain and before durable row
  cancellation. A noncooperative late provider result is drained and rejected;
  it cannot become a completion or clear a newer owner.
- The root state strongly retains the cancellation owner and exact claim until
  the Store proves `retryOperation = null` with the matching durable receipt.
  If bounded immediate retries exhaust, the next Retry entrypoint retriggers
  only an already-terminal cancellation and returns pending while recovery
  runs; an active provider with no cancellation claim remains untouched.
- The retained owner/claim cycle breaks only after exact durable cancellation
  consumption. Persistent failure therefore blocks conflicting work without
  losing same-process recovery authority or requiring provider replay.

## Independent Review Fixes

Three independent read-only reviews found and verified fixes for:

- setup and credential eligibility that were not initially frozen before the
  durable reservation;
- provider completion diagnostics that initially could reflect generic outcome
  payloads;
- reservation-cancellation and coordinator-level commit-uncertainty paths that
  were not initially reconciled as the exact same operation;
- a generic provider TaskLocal flag that could misclassify cancellation from a
  different handoff;
- provider self-cancellation and callback cancellation that could otherwise
  await their own drain;
- cancellation authority that initially became unreachable after handoff
  deinit or an audio-transfer cleanup failure;
- retained authority that was preserved but not initially retriggered by a
  production Retry entrypoint after bounded attempts exhausted;
- missing direct coverage for Pending/Retry exclusion, caller cancellation,
  noncooperative late output, uncertainty at every local boundary, and
  same-process retained recovery.

The final repeated P0/P1 reviews reported no remaining blocker in C4.4A.
Caller-mintable credential eligibility remains acceptable only while this
surface is module-internal; C4.5 must place the public Retry entrypoint behind
the containing app's fresh credential/setup-owned factory.

## Verdict

P2 C4.4A explicit Retry reservation and live ownership: passed for focused and
full strict package tests, release build, macOS, iOS simulator, public API
isolation, keyboard binary isolation, exact uncertainty recovery, and
independent review.

The next checkpoint is C4.4B: descriptor-backed Transcription, transient
Translation, timeout and provider-error mapping, late-result rejection,
retry-count idempotency, and non-authoritative Usage recording. No partial
History or Retry UI ships from C4.4A.
