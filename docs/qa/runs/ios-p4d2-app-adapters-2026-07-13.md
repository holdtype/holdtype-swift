# iOS P4D-2B App Adapters QA

Date: 2026-07-13
Milestone: P4D-2B containing-app platform adapters

## Decision

P4D-2B code is complete. The containing-app target now has fake-backed,
fail-closed adapters for iOS microphone permission, foreground audio-session
configuration and events, bounded finalization background assertions,
voice-boundary feedback, and the recorder candidate. The containing app owns
the only microphone purpose string.

This is not approval of P4D-2 or P4 for release. `AVAudioRecorder` remains only
a fail-closed candidate until P4D-2C proves source identity and runtime behavior
on a physical iPhone or iPad. No qualifying device was available for this run.
P4D-2A2 descriptor-bound completed-source transfer to Pending remains a
separate in-progress Persistence checkpoint.

P4D-2B adds no Voice UI, process workflow composition, audio background mode,
Speech permission, keyboard dependency, Full Access requirement, provider
request, or live Keychain operation.

## Delivered Contract

- The permission adapter reads `AVAudioApplication` state, requests only while
  undetermined, coalesces concurrent requests, and maps unknown values to an
  unavailable state.
- The audio-session adapter uses exactly `playAndRecord`, mode `default`,
  `allowBluetoothHFP`, and `defaultToSpeaker`; it disables haptics and system
  sounds during recording and deactivates with `notifyOthersOnDeactivation`.
- Stable interruption, route, input-mute, media-lost, and media-reset events
  cross one serialized FIFO bridge. Attempt token and observation generation
  reject replaced, cancelled, and late callbacks. Interruption end carries no
  resume authority.
- The finalization adapter owns at most one named `UIApplication` assertion,
  races system expiration against an exact ten-second monotonic watchdog, and
  ends the assertion exactly once.
- Boundary feedback occurs only before retained capture or after recorder
  close. Start cue completion, failure, interruption, caller cancellation, and
  the exact two-second watchdog converge on one exact-once stop. Cancel and
  interruption have no success cue. Synchronous factory/player callbacks are
  generation-checked and cannot restart a completed boundary.
- The recorder candidate receives its transient URL only inside the opaque
  descriptor-bound lease callback. It creates exact mono AAC at 44.1 kHz with
  high encoder quality, revalidates after recorder initialization and after
  `prepareToRecord()`, and uses a 300-second product watchdog ahead of a
  301-second recorder safety cap.
- Explicit Done durably begins finalizing before recorder stop, then completes
  only after recorder close. Cancel begins discarding before stop and finishes
  discard after stop. Every failure stops once and either completes, discards,
  or releases the exact source for local recovery.
- Recorder delegate delivery is an additional stop authority, not the only
  one. Task cancellation, explicit action, interruption, token/generation,
  watchdog, and delegate paths converge on the same idempotent owner.
- Recorder `currentTime` is presentation-only. Completed duration and byte
  count come only from bounded Persistence validation after recorder close.

## Automated Evidence

- Unified signed iOS Simulator adapter test run with warnings as errors
  - Command selected
    `IOSMicrophonePermissionAdapterTests`, `IOSAudioSessionAdapterTests`,
    `IOSForegroundFinalizationBackgroundTaskTests`,
    `IOSVoiceBoundaryFeedbackAdapterTests`,
    `IOSVoiceRecorderAdapterTests`, and `IOSVoicePlatformPlistTests`.
  - The environment used `HOLDTYPE_AUTOMATION=1` and
    `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip`.
  - Result: 50 tests in 6 suites passed; log
    `/tmp/holdtype-p4d2b-app-adapters-tests.log`.
- Universal Debug iOS Simulator build with warnings as errors
  - Destination: `generic/platform=iOS Simulator`.
  - Result: passed; log `/tmp/holdtype-p4d2b-universal-debug.log`.
- Release iOS app build with warnings as errors
  - Destination: `generic/platform=iOS Simulator`.
  - Result: passed; log
    `/tmp/holdtype-p4d2b-release-ios-20260713-1.log`; DerivedData
    `/tmp/holdtype-p4d2b-release-ios-20260713-1`.
- Plist and project validation
  - `plutil -lint` passed for `HoldTypeIOS/Info.plist`,
    `HoldTypeKeyboard/Info.plist`, and the Xcode project.
  - The built containing-app plist contains exactly
    `NSMicrophoneUsageDescription = HoldType uses the microphone to record
    speech you choose to transcribe.`
  - The app and keyboard plists contain no Speech purpose string or audio
    background mode. The keyboard contains no microphone purpose string.
- Release keyboard isolation
  - Both architecture source lists contain only `KeyboardViewController.swift`
    and `KeyboardBridge.swift`; both link lists contain only their matching
    object files.
  - The keyboard target has no target dependency or package product
    dependency. Both generated dependency-metadata lists are empty.
  - The processed extension remains `com.apple.keyboard-service` with
    `RequestsOpenAccess = false`; its processed simulator entitlement
    dictionary is empty.
  - `otool -L` reports only Foundation, UIKit, Objective-C, system, and Swift
    runtime libraries. `nm -gU` with Swift demangling, `strings`, and an entire
    appex byte scan found no HoldType Domain, IOSCore, Persistence, OpenAI,
    permission, audio-session, background-finalization, feedback, recorder,
    AVAudioSession, AVAudioRecorder, AVAudioApplication, microphone-purpose,
    Speech-purpose, or background-audio dependency/symbol/string.
  - Standalone and embedded extension executables are byte-identical with
    SHA-256
    `499b5576fa708d425565f35c398e17d63dc1ba37f352762485de204605d47db3`.
- `git diff --check`
  - Result: passed before the documentation checkpoint.

The expected Xcode AppIntents metadata warning reports that extraction was
skipped because the targets do not depend on AppIntents. Swift compilation and
tests ran with warnings as errors and passed.

## Self-Audit And Redaction

The final audit covered permission request coalescing, unknown-state failure,
audio configuration options, FIFO event order, current-route reinspection,
stale generation rejection, exact-once assertion end, feedback reentrancy,
start and maximum-duration watchdogs, Task cancellation during both recorder
checkpoints, Done/cancel storage ordering, invalid capture outcomes, delegate
lateness, stop idempotency, and exact-source preservation. No unresolved P4D-2B
contract finding remained.

Adapter clients, tokens, leases, results, and owners use redacted public
descriptions and empty mirrors where they could otherwise reveal authority or
identity. Diagnostics and mapped failures are finite payload-free values; raw
URLs, UUIDs, route UIDs, arbitrary errors, audio bytes, and provider text do
not cross those diagnostic seams. Canary tests cover those surfaces.

All test feedback, recorder, permission, audio-session, and background clients
were fakes. Verification did not request microphone permission, activate a live
audio session, record or play audio, emit a real haptic, begin a real background
assertion, contact OpenAI, use an API key, read or write live Keychain data,
enable keyboard Full Access, or add production composition.

## Remaining Gates

- P4D-2A2 remains the separate in-progress Persistence handoff from an opaque
  completed capture source into canonical Pending ownership.
- P4D-2C remains pending. A physical device must prove the exact inode, xattrs,
  protection, owner, mode, link count, and path agreement across recorder
  initialization, prepare, recording, and close, then cover real permission,
  route, interruption, lock, cue, microphone-indicator, and expiration behavior.
- If P4D-2C fails the recorder identity proof, replace `AVAudioRecorder` with a
  descriptor-backed AudioToolbox/AVAudioEngine writer without weakening the
  frozen storage contract.
- P4D-3 still owns production process composition and Voice UI. P4D-2B itself
  wires neither surface.

P4D-2 and P4 remain not release-ready until their remaining storage,
physical-device, composition, and product gates pass.
