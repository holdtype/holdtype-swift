# iOS Failed History Capability Foundation QA

Date: 2026-07-11
Milestone: P2 C4.2A physical-root gate, capability, and mutation foundation

## Scope

- Give every canonical physical Application Support root one process operation
  gate, PendingRecording owner registry, Pending store identity, failed store,
  failed-mutation interlock, and coordinator state.
- Add store-minted failed-journal mutation capabilities and receipts bound to
  the exact store, owner, active gate lease, physical root, source snapshot,
  and intended next revision.
- Preserve exact visible and invisible commit uncertainty and block unrelated
  Pending, accepted-History, outbox, policy-cutover, and coordinator work until
  the same mutation is reconciled.
- Consume the expected device and inode inside irreversible strict-journal and
  pending-audio filesystem operations before their first side effect.
- Require failed-journal staging maintenance to use the same active root lease,
  physical-root authorization, and fail-closed interlock.
- Validate retry media through an already-open descriptor, serialize timed-out
  AudioToolbox workers per physical root, and hand providers only a bounded,
  revocable descriptor-backed audio source.
- Treat physical-root replacement as a sticky conflict across direct paths,
  aliases, symlink-target replacement, and symlink-to-directory replacement,
  while still allowing a genuine symlink retarget to join a healthy root.

Row-first PendingRecording transfer, metadata-only retirement, relaunch resume,
sealed audio inventory, retention, Delete, tombstone cleanup, policy-cutover
integration, explicit Retry, public History UI, and keyboard behavior remain
C4.2B through C4.5.

## Automated Evidence

- `swift test --package-path Packages/HoldTypePersistence -Xswiftc
  -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 671 tests in 30 suites.
- Focused failed-store, Pending-store, audio-filesystem, and coordinator runs
  passed. Adversarial coverage includes exact visible/invisible uncertainty,
  root swaps, alias bypass attempts, symlink-to-directory replacement, pinned
  WAV and AAC/M4A validation, validator timeout and late descriptor release,
  provider-source invalidation, and a transient path swap during provider read.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test -quiet`
  - Result: passed, 441 tests, 0 failed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' test -quiet`
  - Result: passed, 1,034 tests, 0 failed, 0 skipped, on iPhone 16 Pro running
    iOS 18.6.
- The matching HoldType-iOS simulator `build` action passed and produced the
  containing app with its keyboard extension.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: failed-store capabilities, receipts, journals, interlocks, physical
    root identity, raw descriptor, and `FileHandle` remain internal. The
    intentional public `IOSPendingTranscriptionAudio` surface contains only
    format, duration, byte count, a 64 KiB maximum, bounded async read, and
    redacted diagnostics; `IOSPendingTranscriptionExecutor` receives that
    source instead of a path-bearing artifact. The payload-free
    `localRecoveryPending` and `repositoryIdentityConflict` error cases remain
    public as designed.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: no Domain, Persistence, IOSCore, OpenAI, PendingRecording,
    accepted-History, policy, failed-History, or root-identity linkage or symbol
    is present.
- `git diff --check`
  - Result: passed.

## Verified Capability And Root Contract

- Public coordinators and Pending stores resolving the same physical root share
  exactly one gate and live-owner/interlock state; different roots remain
  independent. Replica Pending actors keep distinct opaque store identities.
- A failed mutation can start only under its bound active root lease. Create
  requires revision one; replacement requires exactly current revision plus
  one. Foreign stores, owners, roots, gates, expired leases, stale snapshots,
  stale receipts, and invalid revision steps fail before mutation I/O.
- Visible and invisible commit uncertainty retain the exact source/outcome pair.
  Only the identical retry can reconcile it. An unknown durable winner remains
  blocked instead of clearing the interlock or accepting unrelated work.
- A receipt is not trusted as cached success: validation reloads and requires
  the exact current physical snapshot while the same lease and root are still
  active.
- Root checks are not merely bracketing probes. The strict journal and audio
  filesystem compare the expected device/inode with the opened Application
  Support descriptor before `mkdir`, publish, replace, remove, or staging
  cleanup, then continue descriptor-relative.
- Registry classification is fail closed for a direct missing path becoming a
  directory, same-path replacement, replacement of a symlink target, and a
  registered symlink being replaced by a directory. Both the old and new
  physical roots are tombstoned, restoring the old path does not clear the
  conflict, and a new alias cannot bypass it. Only a path that was and still is
  a symlink may perform the genuine retarget case and join its healthy target.
- The adversarial barrier test replaces the root after store prevalidation but
  before the journal opens it. The replacement root receives no failed-journal
  bytes. A separate audio test proves a mismatched opened root creates no
  directory and publishes no bytes.
- Interlock mutation is owned only by `IOSFailedHistoryStore`; coordinator
  composition rejects a Pending store wired to a different interlock before
  repository I/O.
- Staging maintenance now requires an active bound gate lease, observes the
  uncertainty interlock, consumes the expected root inside the strict
  filesystem, and revalidates on success and error.
- Policy-command error mapping revalidates an inner strict-root mismatch:
  pre-boundary failures become the typed repository conflict, while work that
  may have crossed a logical boundary remains pending local recovery.

## Verified Descriptor And Provider Contract

- Media validation duplicates the already-open audio descriptor and uses
  AudioToolbox callbacks backed by bounded `pread`; it never reopens the public
  path. Real WAV and AAC/M4A files round-trip with checked format, sample rate,
  channel count, frame length, and duration.
- A two-second validator timeout cannot close a descriptor under an active
  callback. The physical-root worker gate blocks duplicate same-root work until
  the late worker exits and releases its descriptor; another root stays
  independent and the original gate is reusable afterward.
- The provider receives only `IOSPendingTranscriptionAudio`. Reads are capped at
  64 KiB and remain bound to the validated descriptor even if the pathname is
  temporarily replaced. No URL, `FileHandle`, or raw descriptor crosses the
  public API.
- The source stays alive through the executor call, rejects use immediately
  after success, failure, cancellation, recovery, or Store retirement, and
  defers descriptor close until any in-flight bounded read has finished.

## Independent Review Fixes

Read-only reviews found and verified fixes for:

- a check/use race between outer root validation and the repository's internal
  open;
- the first root-bound fix covering only failed/Pending/audio while policy,
  accepted History, outbox, and delivery still used unbound strict-journal
  opens; all same-root strict repositories now consume one configured identity;
- a swap-detect-restore sequence that could previously hide the mismatch from
  the outer postcheck; low-level mismatch now invalidates the shared context
  immediately and permanently;
- caller-selectable interlock identity in injected coordinator composition;
- store-local uncertainty that did not initially block all same-root owners;
- a capability that was not initially bound to the physical repository;
- unknown-winner and stale-receipt paths that could otherwise release or reuse
  authority too early;
- failed staging maintenance that initially lacked an active root lease;
- canonical Pending stores and public replicas that initially did not preserve
  both one shared physical owner and distinct actor identities;
- lexical aliases that could briefly diverge from their canonical root without
  tombstoning both physical identities, including a registered symlink replaced
  by a direct directory and a replacement reached through a fresh alias;
- a path-based AVFoundation media probe that could validate replacement bytes
  instead of the already-open file, replaced by descriptor-backed AudioToolbox
  validation;
- timeout handling that initially allowed another same-root media worker while
  the first worker still held its duplicated descriptor;
- a detached validator task that could starve behind the package test workload,
  moved to its bounded dedicated dispatch queue without weakening lifetime
  rules;
- a provider executor boundary that initially accepted a path-bearing recording
  artifact, replaced by the bounded revocable descriptor source;
- inner strict-root failures whose pre/post logical-boundary error mapping was
  not initially preserved by the policy coordinator.

The final repeated P0/P1 reviews reported no remaining blocker in C4.2A. The
ordinary Pending retry/discard interlock after a durable failed-row commit is
intentionally assigned to C4.2B, where that production row commit first exists.

## Verdict

P2 C4.2A capability/root-gate foundation: passed for strict package tests,
macOS, iOS simulator, public API isolation, keyboard binary isolation, root
replacement adversarial coverage, and independent review.

The next checkpoint is C4.2B: row-first PendingRecording ownership transfer,
metadata-only journal retirement, exact absence proof, and provider-free
relaunch reconciliation. No partial failed-History or Retry UI ships from this
checkpoint.
