# iOS P4D-2A2 Capture Transfer QA

Date: 2026-07-13
Milestone: P4D-2A2 completed capture to canonical Pending handoff

## Decision

P4D-2A2 is complete. The production foreground-capture owner now transfers an
opaque completed source into the one canonical Pending transaction without
exposing a path, descriptor, reusable file authority, or partially published
happy path. Explicit relaunch recovery and provider-free launch reconciliation
share the same process-owned root gate and preserve every ambiguous artifact.

This is not approval of P4D-2 or P4 for release. P4D-2C still requires the
frozen source-identity and foreground-audio matrix on a physical iPhone or
iPad. P4D-3 composition, Voice UI, and the remaining product gates keep their
own exit criteria.

## Delivered Contract

- A completed capture and a launch-recovery observation carry only opaque,
  source-root-bound capabilities. Production callers cannot reopen an ordinary
  source path or manufacture recovery authority. The production foreground
  Voice owner exposes the legacy path-based prepare entry point only in Debug;
  the underlying Store retains it for fixtures and older internal flows.
- Pending copies in bounded 64 KiB reads from the still-held source descriptor.
  An exact 51-byte binary transfer binding covers schema, attempt, source
  device/inode/generation, output intent, format, duration, and byte count.
- Normal Done and explicit Recover are distinct modes. Done creates
  `readyForTranscription` from the frozen capture settings. Recover creates or
  adopts `awaitingRecovery` with current compact settings and still requires an
  explicit Retry before provider work.
- Empty, prefix-only, incomplete, complete, media-invalid, malformed,
  mismatched, foreign, and ambiguous staging/final states have explicit
  fail-closed outcomes. Only explicit Recover may repair an exact incomplete or
  media-invalid transfer; passive launch does not recopy it.
- A new Pending journal create is immediately followed by a same-phase durable
  confirmation before source retirement. Existing matching journals are also
  confirmed and retain their frozen settings and timestamps.
- Passive launch may retire exact preparing state only after revalidating the
  matching journal, final transfer binding, protected-audio inventory, and held
  lease. Missing or incomplete state remains recoverable and provider-free.
- Source retirement distinguishes confirmed removal from durable transferred
  state with cleanup still pending. Cleanup uncertainty does not revoke
  canonical Pending ownership or report bytes as removed.
- Cancellation and timeout keep the source operation and descriptor lease alive
  until a late worker actually exits. Stale completed/preparing capabilities,
  cross-root capabilities, inode changes, and destination ambiguity fail closed.
- External transfer and media validation work remains explicitly bounded. File
  descriptors are released across publication, final-directory sync, staging
  removal, cancellation, timeout, and retry paths.

## Automated Evidence

- Focused strict capture-transfer package run
  - Result: 41 tests in 3 suites passed.
  - Covered codec bounds, descriptor transfer, crash matrix, normal Done,
    explicit and passive recovery, journal uncertainty, stale capabilities,
    cleanup-pending reporting, descriptor leaks, cancellation, and timeout.
  - Log: `/tmp/p4d2a2-capture-final2.log`.
- Full serialized Persistence run with strict concurrency and warnings as errors
  - Result: 1,096 tests in 57 suites passed.
  - Log: `/tmp/p4d2a2-full-persistence.log`.
- Release package build with strict concurrency and warnings as errors
  - Result: passed.
  - Log: `/tmp/p4d2a2-release-package.log`.
- Universal Release iOS Simulator build with warnings as errors
  - Destination: `generic/platform=iOS Simulator`.
  - Result: passed.
  - Log: `/tmp/p4d2a2-release-ios.log`.
- Non-Debug Release dispatch harness
  - A disposable external executable first completed the required
    provider-free process-launch recovery, then used the public
    `IOSForegroundVoicePersistenceOwner` boundary to create a real one-second
    AAC/M4A capture, close it, and call `prepareCompletedCapture` through the
    production Store existential.
  - Result: `RELEASE_STORE_DISPATCH_PASS`, `readyForTranscription`, 1,000 ms,
    57,528 bytes.
  - Log: `/tmp/p4d2a2-release-dispatch-harness.log`.
- Full signed iOS Simulator scheme test with warnings as errors
  - Destination: iPhone 16, iOS 18.6.
  - Environment: `HOLDTYPE_AUTOMATION=1` and
    `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip`.
  - Result: 1,693 tests in 162 suites passed.
  - Log: `/tmp/p4d2a2-ios-simulator-wae-signed.log`.

The non-Debug harness was necessary because SwiftPM Release testing compiles
the package's entire test target, including older tests that intentionally call
Debug-only consent test hooks. The harness imports only production modules and
therefore verifies the Release protocol witness and Store path directly.

An initial unsigned Simulator invocation executed the full suite but left the
hosted app's access-group prefix unresolved, so the existing hosted-plist test
correctly failed. The canonical signed Simulator rerun above passed all tests.

## Review And Safety

An independent storage and recovery audit reviewed Release witness dispatch,
opaque authority, root-gate ownership, normal/recovery/passive modes, journal
confirmation order, passive retirement proof, late-worker lifetime, stale CAS,
destination ambiguity, and crash adoption. The final audit found no remaining
P0, P1, or P2 issue.

Verification used fake-backed storage tests and a silent local Release audio
artifact. It did not request microphone permission, activate a live audio
session, contact OpenAI, use an API key, read or write live Keychain data,
enable keyboard Full Access, or perform destructive remote or database work.

## Remaining Gates

- P4D-2C must prove the frozen recorder/source identity, data protection,
  permission, route, interruption, lock, cue, microphone-indicator, and bounded
  finalization matrix on a physical iPhone or iPad.
- A failed P4D-2C identity proof selects a descriptor-backed
  AudioToolbox/AVAudioEngine writer without weakening this transfer contract.
- P4D-3 still owns production process composition and Voice UI.
- Keyboard bridge, physical external-app insertion, and release-product gates
  remain separate.
