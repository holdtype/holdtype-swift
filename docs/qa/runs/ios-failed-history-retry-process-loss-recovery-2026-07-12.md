# iOS Failed History Retry Process-Loss Recovery QA

Date: 2026-07-12
Milestone: P2 C4.4D provider-free process-loss recovery and integration

## Scope

- Close ordinary PendingRecording, accepted-delivery, and failed-History work
  behind a shared cold-start retry scan in each new production context.
- Recover interrupted `reserved`, `providerDispatched`, and `acceptingOutput`
  Retry states without contacting a provider or reconstructing accepted text
  from caller input.
- Distinguish a matching tagged Retry delivery, a wholly unrelated frozen
  predecessor, and every partial, cross-field, semantic, temporal, or storage
  collision.
- Continue exact accepted-History and row-to-audio-tombstone work after
  relaunch, including commit uncertainty and post-expiry protected completion.
- Integrate recovery with History policy cutover without another generation,
  bypassing retained cutover ownership, or exceeding one failed-domain action
  per policy-cleanup call.
- Keep the recovery entrypoint and every bearer capability module-internal,
  redacted, app-private, and absent from the keyboard extension.

C4.5 still owns containing-app lifecycle scheduling, public redacted app
results, and the final C4 user-facing boundary.

## Automated Evidence

- `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test
  --package-path Packages/HoldTypePersistence --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 882 tests in 47 suites.
- Focused strict suites:
  - Retry relaunch recovery: 33/33 passed.
  - Fresh production-context relaunch: 1/1 passed across all three durable
    Retry states.
  - Failed/delivery interlock: 9/9 passed.
  - Retry coordinator: 22/22 passed.
  - Accepted History and policy integration: 136/136 passed.
- `swift build --package-path Packages/HoldTypePersistence -c release
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test -quiet`
  - Result: passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' test
  -quiet`
  - Result: passed on iPhone 16 Pro running iOS 18.6.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: relaunch directives, reservations, relations, recovered receipts,
    entrypoint, `failedRetryID`, and durable failed-Retry internals remain absent
    from the public graph.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: only expected system linkage; no Domain, Persistence, IOSCore,
    OpenAI, PendingRecording, failed History, Retry, Usage, Keychain,
    accepted-output, or accepted-History dependency entered the keyboard.
- `git diff --check`
  - Result: passed.

No verification command contacted OpenAI, invoked a live provider, or used a
live API key.

## Verified Cold-Start And Relaunch Boundary

- A new production process context starts in `recoveryScanRequired`. Ordinary
  same-root capture, PendingRecording, delivery reads/mutations, and failed
  mutations remain closed until strict failed-root inspection proves the next
  state.
- Missing or valid empty failed storage opens the barrier without delivery I/O.
  Corrupt, future-schema, unavailable, foreign-root, rollback-ambiguous, or
  uncertain storage preserves bytes and keeps the barrier closed.
- `reserved` and `providerDispatched` recover by proving that no compatible
  accepted delivery exists, then clearing only the exact operation. The row,
  audio ownership, failure category, retry count, and `updatedAt` remain intact.
- `acceptingOutput` first restores the exact failed/delivery relation. A missing
  slot or unchanged wholly unrelated predecessor clears the operation; a
  matching tagged delivery continues only local acceptance, History, and
  row-to-tombstone work.
- The real-filesystem relaunch test writes production journals, creates a fresh
  registry/context with new owner and store identities, and recovers all three
  states. It does not reuse the original actors or process-local capabilities.

## Verified Identity, Semantics, And Time

- Wholly unrelated means set-disjoint across all four delivery identities and
  a different failed-Retry tag. Aligned, cross-field, partial, exact-untagged,
  and wrong-tag collisions fail closed in both live freeze and relaunch paths.
- A matching delivery must also preserve pending delivery state, publication
  generation zero, automatic insertion off, exact output intent, exact History
  generation/model/language/duration, valid accepted text, and a non-replacement
  History marker.
- `keepLatestResult` is now a required strict Boolean in the durable Retry
  operation. Reservation freezes it, every state transition preserves it, live
  acceptance consumes it, and relaunch rejects a delivery with a different
  value.
- Future failed-row timestamps, future exact terminal deliveries, and future
  unrelated predecessors are rollback-ambiguous. Recovery preserves both
  stores and their interlock instead of cancelling or tombstoning the row.
- Expired but temporally valid exact Retry delivery may finish only the
  relation-protected local History and success path; its immutable expiry and
  unrelated ordinary behavior remain unchanged.

## Verified Policy And Uncertainty Behavior

- A state-changing Clear/Disable/Enable commits generation N+1 before touching
  the old Retry. Each policy-cleanup call performs at most one durable
  failed-domain action and later calls continue under the same receipt.
- Before that policy mutation, the failed root is strictly read under the
  captured generation N receipt. A row or tombstone already claiming N+1 is
  preserved and rejects every Clear/Disable/Enable command before policy or
  failed bytes change.
- Standalone recovery returns pending while any policy-cutover owner remains;
  it cannot bypass pre-boundary or post-boundary cutover phases.
- A durably confirmed policy no-op preserves retry bytes and generation N,
  releases cutover ownership, and lets later standalone lifecycle recovery
  finish the Retry without creating generation N+1 or N+2.
- Source-visible and outcome-visible failed-store uncertainty reuse only the
  exact retained intent. Durable receipts retire the interlock without an
  additional fallible post-commit read.
- A retained relaunch reservation may refresh with the exact same policy state
  or a strictly newer generation only. Same-generation enabled/disabled
  equivocation and generation rollback preserve both stores and stay pending.
- Delivery/History uncertainty requires exact refreshed records and accepted
  bytes. Substituted text, marker, provenance, or terminal state leaves the
  relation protected and returns pending.
- Concurrent standalone recovery serializes through the root gate: one caller
  commits the terminal result and the other observes no work.

## Independent Review Fixes

Independent read-only reviews found and verified fixes for:

- standalone recovery initially bypassing retained History policy ownership;
- confirmed policy no-op initially retaining an unrecoverable cutover owner;
- live freeze initially treating cross-field UUID reuse as unrelated;
- conflict reconciliation initially using field-aligned rather than set-wide
  identity matching;
- collision coverage initially omitting a matching Retry tag paired with four
  otherwise set-disjoint delivery identities;
- relaunch initially lacking an independent durable Keep Latest value;
- exact History recovery coverage initially varying only the model rather than
  generation, model, language, and duration independently;
- delivery and failed-root future timestamps initially reaching only partial
  temporal checks;
- same-generation policy equivocation initially passing a merely nondecreasing
  reservation check;
- a failed row or tombstone pre-claiming the command's N+1 generation initially
  becoming indistinguishable from current state after the policy commit;
- insufficient real-context relaunch, collision, storage-error, and redaction
  coverage.

After those fixes, three fresh read-only final reviews covering security and
fail-closed behavior, integration and module boundaries, and tests/spec/QA all
returned clean.

## Verdict

P2 C4.4D provider-free Retry process-loss recovery: passed for strict focused
and full package tests, release build, macOS regression, iOS simulator,
production-context relaunch, policy integration, mutation uncertainty, temporal
rollback, public API isolation, keyboard binary isolation, privacy, and
independent review.

The next checkpoint is C4.5: invoke these provider-free operations from the
containing-app lifecycle, expose only redacted app-facing status/actions, repeat
the full regression, and record the final C4 verdict.
