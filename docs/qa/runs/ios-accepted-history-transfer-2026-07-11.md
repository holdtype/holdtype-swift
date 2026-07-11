# iOS Accepted History Pending Transfer QA

Date: 2026-07-11
Milestone: P2 exact pending-delivery transfer and atomic replacement checkpoint

## Scope

- Extend normal coordinator acceptance across an occupied active delivery whose
  accepted-History marker is still pending.
- Confirm the old delivery and current policy, then either durably transfer the
  exact payload to outbox or cancel a stale marker with newer policy authority.
- Permit replacement only with an outbox receipt bound to the exact refreshed
  delivery authorization.
- Continue the new delivery as fresh acceptance, including its normal row and
  marker decision.
- Preserve exact transfer/replacement phases across local uncertainty and let
  provider-free recovery finish them.
- Bind the transfer lease to the exact delivery-store/outbox-store pair, allow
  only one outbox claimant, and enforce consume/release plus monotonic expiry.
- Cover replacement-only capacity rejection whose prepared not-retained receipt
  becomes durable only through the exact terminal delivery marker.
- Require exact owner-bound delivery authorization for the mutually exclusive
  bridge reservation and freeze the authorized snapshot while either
  reservation is active; C1 still performs no bridge publication.
- Record the no-downgrade release constraint introduced by the
  `pendingReplacement` wire value.
- Keep every record, capability, and operation app-private and outside the
  keyboard and App Group.

The FIFO outbox worker and policy-cutover cleanup remain the next checkpoint.

## Automated Evidence

- `swift test --package-path Packages/HoldTypePersistence -Xswiftc
  -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 518 tests in 25 suites.
- `swift test --package-path Packages/HoldTypePersistence --filter
  IOSAcceptedHistoryCoordinatorTests`
  - Result: passed, 67 tests.
- Focused accepted-History outbox, row-store, and delivery-store suites
  - Result: passed, respectively 32, 47, and 69 tests.
- `swift test --package-path Packages/HoldTypePersistence --filter
  IOSAcceptedOutputDeliveryStoreTests`
  - Result: included in the focused result above after the bridge-proof fixture
    was changed to use a retained-row receipt for the intentionally impossible
    generation-one/outbox combination.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: passed; no live provider or credential was used.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=<verified-live-simulator-id>' test`
  - Result: passed through XcodeBuildMCP, 881 tests, 0 failures, on the
    live-discovered iPhone 16 Pro iOS 18.6 simulator
    `AFB49941-79A4-400A-AA0F-9E962155E485`.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: passed. The raw History stores, receipts, pending-replacement work,
    reservations, and transfer operations are absent from the public surface;
    the intentional `IOSAcceptedOutputHistoryWriteState.pendingReplacement`
    case is public with its containing delivery value.
- `otool -L` and `nm -gU` on the simulator keyboard executable and debug dylib
  - Result: the executable links only its debug dylib and the system loader;
    the dylib links UIKit/Foundation/system/Swift runtimes. No Domain,
    Persistence, OpenAI, IOSCore, accepted-History, History-policy, or accepted
    delivery symbol was found.
- `git diff --check`
  - Result: passed after all implementation, review, spec, plan, and QA fixes.

## Verified State And Durability Assertions

- The existing FIFO/non-reentrant coordinator lease covers old-delivery
  authorization, reservation minting, policy confirmation, outbox transfer,
  proof-bound replacement, and the new delivery's normal History decision.
- C1 only makes the in-memory bridge-publication and pending-History transfer
  reservations mutually exclusive. The bridge reservation requires the exact
  owner-bound delivery authorization created by the mandatory identical
  rewrite, not an expectation or caller assertion. C1 does not perform
  generation `0 -> 1` or write App Group state; P6 must consume the bridge
  reservation in that actual ordered flow. Either active reservation freezes
  the exact snapshot and blocks every non-consuming delivery mutation,
  including a History-marker transition, before delivery-journal I/O. Foreign
  capability owners fail before delivery-journal I/O.
- Production delivery and outbox stores share one injected delivery-store
  identity; a mismatched pair fails before repository I/O. The monotonic
  transfer lease can be claimed by one outbox-store identity only. First claim
  after expiry performs no outbox I/O; a claim made while live may cross expiry
  only to confirm an already-visible exact transfer. Invisible intent clears
  and expires. Successful replacement consumes the lease, while definitive
  pre-replacement expiry or conflict releases it; either state revokes reuse.
- Visible and invisible outbox-transfer uncertainty retain the same
  preparation, delivery authorization, and transfer reservation; after mint,
  that reservation supersedes the policy receipt instead of retaining it as
  separate authority. Different accepted work cannot take over the phase.
- Visible and invisible delivery-replacement uncertainty retain the exact
  outbox receipt. A same-process retry resumes the exact new-delivery History
  decision; after process loss, the store-minted `pendingReplacement` marker
  authorizes its idempotent replay, so an absent new row is not silently skipped.
- If replacement row retention loses to capacity, the store identically
  rewrites the exact source envelope with logical revision, entries, and stale
  rows unchanged. Visible and invisible uncertainty retain the prepared mode.
  The receipt is not independently durable: only the exact terminal marker CAS
  seals it. Process loss before that marker re-evaluates the replacement-only
  row decision; process loss after it performs no row work.
- Exact row, terminal-marker, transfer, and replacement uncertainty keep their
  phase-specific authorization and retry only the matching local CAS or
  identical confirmation. Different work and reconstructed caller assertions
  cannot take over a retained phase.
- A strictly newer policy cancels the old marker without writing outbox, then
  the new delivery follows its own captured generation.
- Process-loss recovery re-authorizes the old delivery, identically confirms an
  existing outbox entry at the same logical revision, and obtains a fresh
  delivery-origin receipt before replacement.
- If expiry wins during an invisible transfer, ordinary acceptance atomically
  replaces the expired slot. There is no delivery unlink/create gap and no new
  outbox entry.
- Provider-free recovery can finish retained in-process transfer and then
  complete the new row/marker decision.
- A binary that can persist `pendingReplacement` is a no-downgrade release: an
  older decoder preserves the unsupported file and cannot reach its 24-hour
  expiry cleanup. Re-upgrade, uninstall, or a future explicit compatible
  recovery path is required to clear that wedge.

## Independent Review

Initial read-only state-machine, capability-security/API, and spec/Apple-privacy
reviews produced C1 correctness findings. Their fixes are present in this
checkpoint. All three independent follow-up reviews found no remaining P0/P1
issue.

## Gate Decision

P2 pending-delivery transfer and atomic replacement: passed for this
containing-app-only code checkpoint.

This is not physical-device evidence. Signed-device Complete Data Protection,
locked-device behavior, force-quit/process eviction, real App Group bridge
revocation, keyboard enablement, Full Access, and actual insertion remain their
named physical gates.
