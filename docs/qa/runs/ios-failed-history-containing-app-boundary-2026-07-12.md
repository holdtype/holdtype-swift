# iOS Failed History Containing-App Boundary QA

Date: 2026-07-12
Milestone: P2 C4.5 lifecycle recovery and public containing-app boundary

## Scope

- Expose failed History to the containing app through one process-owned,
  payload-minimizing service with load, Delete, and explicit Retry actions.
- Keep Retry sessions, provider configuration, audio descriptors, durable
  receipts, scratch paths, credentials, and repository capabilities outside the
  ordinary public API.
- Resolve every Retry from current app-private Settings, Library, and credential
  state without copying secrets or canonical content into App Group or the
  keyboard extension.
- Run provider-free failed-History, accepted-output, accepted-History,
  policy-cleanup, and PendingRecording recovery at the correct containing-app
  lifecycle opportunities.
- Materialize descriptor-backed Retry audio only in a marked, owner-only,
  Complete-protected, backup-excluded scratch namespace and scavenge bounded
  process-loss orphans without touching source recordings.
- Preserve the existing keyboard binary boundary and all macOS behavior.

## Automated Evidence

- `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test
  --package-path Packages/HoldTypePersistence --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 911 tests in 48 suites.
- `swift build --package-path Packages/HoldTypePersistence -c release
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed.
- `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test
  --package-path Packages/HoldTypeIOSCore --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 50 tests in 5 suites.
- `swift build --package-path Packages/HoldTypeIOSCore -c release
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,name=iPhone 16,OS=18.6' test`
  - Result: 1,305 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-c45-final7-ios.xcresult`.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: 441 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-c45-final7-mac.xcresult`.
- Public symbol graphs for `HoldTypePersistence` and `HoldTypeIOSCore`
  - Result: the ordinary public iOSCore failed-History surface contains only
    `IOSFailedHistoryService` and its load, Delete, and Retry actions. The
    service constructor, Retry session factories, provider adapters, scratch
    machinery, and Persistence's SPI app boundary/session types remain absent.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: no Domain, Persistence, IOSCore, OpenAI, failed-History, Retry,
    Keychain, or containing-app service dependency, symbol, or string entered
    the extension.
- `git diff --check`
  - Result: passed.

No verification command contacted OpenAI, loaded a live API key, or used a live
credential provider.

## Verified Lifecycle And Service Graph

- One composition-owned `IOSFailedHistoryService` serves every app scene. Its
  fixed production graph owns the failed-History boundary, current Settings and
  Library repositories, credential coordinator, provider adapter, and recovery
  entry point without exposing those capabilities to views.
- Direct launch-only tests prove that process-lost `PendingRecording`
  transcription changes to `awaitingRecovery` exactly once at process launch
  and remains unchanged at ordinary foreground opportunities.
- A retained History-policy cutover bypasses the standalone failed-Retry
  preflight, then resumes through its owning cleanup instead of wedging every
  later launch opportunity. The launch-only exact Pending destination check
  runs under that same operation lease before retained or generic expiry work.
- Production PendingRecording recovery now inspects the exact failed-History
  and accepted-output destinations. An exact ordinary accepted destination for
  `outputDelivery` idempotently removes Pending audio and retires its journal,
  including recovery after an audio-first crash. A partial attempt/transcript
  collision, discarded delivery, or corrupt/unavailable prerequisite cannot
  authorize retirement. A discarded exact destination preserves the Pending
  audio and journal for explicit recovery.
- The fixed-service integration test seeds a real failed row and protected
  audio, then proves Retry consumes the current Settings model/language,
  current Library dictionary, and coordinator credential generation, commits
  exact accepted output, and makes no Keychain read or live network call.
- Cancellation after fake provider dispatch returns `cancelled`, publishes no
  accepted delivery, and leaves the failed row retryable.
- Foreground scheduling is coalesced and provider-free recovery never replays a
  provider request. A pending local phase remains available for the next
  lifecycle opportunity.

## Verified Retry Scratch Boundary

- The production-style temporary parent may be owner-matched `0755`, as in an
  iOS sandbox, but the dedicated marked namespace is verified as exact `0700`.
- Every materialized audio file is created owner-only and verified on the same
  descriptor as exact `0600`, Complete-protected, backup-excluded, marked,
  single-link, and exclusively locked before the first source byte is copied.
- The provider reads the pinned descriptor/path identity and final cleanup uses
  descriptor-relative unlink. The scratch URL never enters an ordinary public
  value or log.
- Startup scavenging runs once per process with fixed age, entry, removal,
  byte, and time bounds. It preserves young, active, unmarked, malformed,
  symlinked, hard-linked, raced, and foreign candidates.
- Darwin does not offer a kernel-level conditional unlink against a hostile
  same-UID interposer between final identity verification and removal; the
  app-private sandbox, descriptor checks, and exact namespace are the stated
  boundary.

## Independent Review Fixes

Independent security, integration, and test/spec reviews found and verified
fixes for:

- process-loss audio scratch initially lacking a bounded orphan cleanup path;
- an initial exact-`0700` requirement on the system-provided temporary parent,
  which would reject a normal `0755` iOS sandbox parent;
- production PendingRecording recovery initially using an unconfigured
  destination inspector and therefore never completing launch-only recovery;
- exact accepted output initially leaving `PendingRecording.outputDelivery`
  permanently pending instead of completing its audio/journal retirement;
- audio-first accepted-output retirement initially becoming unreachable after
  relaunch because the ordinary loader rejected the already-removed audio;
- generic accepted-output expiry initially running before exact Pending
  retirement and removing the only durable completion proof;
- retained History-policy cutover initially blocking the standalone cold scan,
  which prevented its own cleanup owner from ever resuming at launch;
- an exact `.discarded` delivery initially being mistaken for accepted output
  and incorrectly authorizing Pending audio and journal removal;
- the fixed service's production initializer initially remaining ordinary
  public API, which allowed scene/view code to construct another root graph;
- missing fixed-service Retry/cancellation integration coverage;
- a roadmap statement that prematurely claimed P3 composition-owned Settings
  and Library state owners already existed.

The repeated final security review reported no remaining high- or
medium-priority finding after these corrections.

## Physical-Device Gates

Simulator evidence cannot establish:

- effective Complete Data Protection while a signed device is locked;
- the signed containing app's real Keychain access group and locked/unlocked
  behavior;
- force quit or process eviction during Retry and subsequent orphan scavenging;
- microphone, provider, background-session, and multi-scene behavior on a
  physical iPhone or iPad.

These remain explicit later device gates and are not represented as completed
by C4.5.

## Verdict

P2 C4.5 passed. The complete C4 failed-History chain now has bounded durable
storage, exact audio ownership, policy cleanup, cancellable Retry, accepted-
output success, provider-free process-loss recovery, a narrow containing-app
surface, protected scratch handling, lifecycle scheduling, full simulator and
macOS regression evidence, and unchanged keyboard isolation.

P2 is complete. The next milestone is P3, beginning with one composition-owned
Settings state owner and one composition-owned Library state owner shared by
all iPhone and iPad scenes and by failed-History Retry before editors are
exposed.
