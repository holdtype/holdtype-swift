# macOS QA Run Report

Date: 2026-07-17 CEST
Task: macOS 1.0.4 hotkey and floating-indicator regression repair
Build/Test: focused tests, full macOS tests, macOS build, and diff hygiene pass
Runtime QA: PASS for the current Xcode build; production artifact still blocked
Tool: Computer Use, `xcodebuild`, release scripts, and read-only artifact checks

## Scenario 1: Manual Recording And Indicator Continuity

### Actions

1. Started a scoped `caffeinate` guard before UI interaction.
2. Launched the fresh debug app, opened the real menu-bar menu, and started and
   stopped recording through its controls.
3. Kept the recording indicator visible for more than 12 seconds and inspected
   31 timestamped frames spread across that interval.
4. Built a signed local 1.0.4 (5) preview, mounted its DMG read-only, launched
   the packaged app, and repeated the menu recording and indicator observation.
5. Inspected the packaged Settings surfaces for permissions and shortcut
   registration.

### Expected

- Manual menu recording remains available independently of the global hotkey.
- The indicator appears while recording and its pulse/orbit animation does not
  restart once per second.
- The packaged app reports the Right Command hold shortcut as registered.

### Observed

- The debug menu recording ran for 51.872 seconds and transcription succeeded.
- The packaged menu recording ran for 52.127 seconds and transcription
  succeeded.
- In both runs the indicator remained visible. Across each 31-frame sequence,
  the orbit dot progressed through distinct positions after more than 12
  seconds instead of snapping back once per second.
- The menu changed to `Recording...` with `Stop Recording` during the active
  session.
- The packaged Settings UI showed Microphone, Accessibility, and Input
  Monitoring as allowed, plus `Right Command - Hold to record` and `Global
  hotkey active`.

### Result

PASS

## Scenario 2: Real Right Command Hold

### Actions

1. Attempted a bounded synthetic Right Command input while the packaged app was
   running; it did not reach the CGSession event tap and was rejected as proof.
2. A physical hold against the earlier preview proved the regression: the
   150 ms reconciliation timer generated release after 0.09-0.35 seconds.
3. Restored the event-tap implementation to the exact 1.0.3 path and removed
   the timer and sampled key-state dependency.
4. The operator compiled the repaired source in Xcode and repeated the physical
   hold test.

### Expected

- One physical key down starts one recording session.
- One physical key up stops that same session exactly once.
- The runtime log contains one `hotkey_event` key down and one key up, followed
  by one recording start and stop.

### Observed

- The synthetic input did not reach the CGSession event tap and produced no
  `hotkey_event`. It remains excluded from the evidence.
- The earlier physical run reproduced premature release repeatedly.
- After the rollback, the operator confirmed from the current Xcode build that
  Right Command remains held until physical release and the bug is fixed.
- Deterministic mapper tests prove direct event key down/up and repeat
  suppression using the same state machine as 1.0.3.

### Result

PASS for the repaired current-source Xcode build.

## Scenario 3: Local Artifact Qualification

### Actions

1. Ran `scripts/release/build_preview_dmg.sh --version 1.0.4 --build 5` with the
   installed Apple Development identity selected through an ignored local
   signing override.
2. Verified the exported app with `codesign --verify --deep --strict` and
   inspected its bundle metadata, hardened-runtime signature, and entitlements.
3. Validated the DMG notarization ticket with `xcrun stapler validate`.
4. Mounted the DMG read-only and launched its packaged app through
   LaunchServices.
5. Inspected the GitHub Actions release workflow, configured secret/variable
   names, and recent run status without reading secret values or triggering a
   workflow.

### Expected

- A local preview can launch and support bounded runtime qualification.
- A publishable replacement must use Developer ID Application signing, be
  notarized, and retain the audio-input entitlement.

### Observed

- Local artifact:
  `dist/preview/v1.0.4/HoldType-1.0.4.dmg`.
- Fresh repaired DMG SHA-256:
  `e534af268581c8e6f15c4bfc08658d2d16f955aa718c1063147f01beaa0ca275`.
- Fresh repaired ZIP SHA-256:
  `ee34d96365020b7f85d065df761150b18e08bfb03e6ad03b22e1fe8d1bf9a3e6`.
- The bundle reports identifier `app.holdtype.HoldType`, version 1.0.4, build 5,
  a valid Apple Development signature, hardened runtime, and
  `com.apple.security.device.audio-input = true`.
- The preview manifest explicitly reports `notarized: false` and
  `public_release: false`; `stapler` confirms that the DMG has no ticket.
- No Developer ID Application identity or configured notarization profile is
  available on this Mac.
- GitHub Actions has all production signing, notarization, Sparkle, and update
  secret names required by `.github/workflows/release.yml` configured. Recent
  release workflow runs include successful notarized publication runs.
- The workflow builds, notarizes, and publishes in one job. No run was started
  without explicit publication authorization.

### Result

PASS for local runtime qualification; BLOCKED for public release eligibility.

### Blocker

After the physical hotkey gate passes, use the configured CI release lane to
build the final Developer ID artifact, notarize and staple it, then repeat the
hotkey and indicator smoke from that packaged artifact before treating it as a
replacement candidate.

## Evidence

- Runtime log:
  `~/Library/Caches/HoldType/Diagnostics/RuntimeLogs/runtime-20260717.log`.
- Focused hotkey and indicator/controller test runs passed.
- `GlobalHotkeyServiceTests/rightCommandMapperEmitsHoldEvents` proves direct
  press/release and repeated key-up suppression; the dedicated key-down and
  key-up tests prove that the event's own flags are authoritative.
- `DictationSessionControllerTests/recordingCountdownPublishesOnlyChangedValues`
  proves unchanged pre-countdown ticks and repeated cleanup do not publish.
- `FloatingIndicatorPresentationTests/coordinatorDeliversRealRuntimeStatusChangeExactlyOnce`
  proves a real runtime status transition reaches the presenter once.
- `FloatingIndicatorPresentationTests/panelControllerRemainsNonActivatingAndInputTransparentAcrossHideShow`
  proves the same panel and host survive hide/show while remaining borderless,
  nonactivating, non-key, non-main, and mouse-transparent.
- Full `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test` passed.
- Full `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' build` passed.
- `git diff --check` passed.
- No dictated text, raw audio, provider payload, or credential was retained as
  QA evidence.

## Acceptance Audit

| Requirement | Status | Authoritative evidence |
| --- | --- | --- |
| Real Right Command starts recording | PASS | Operator physical test of the repaired Xcode build |
| Release stops the same session once | PASS | Operator physical test plus deterministic direct-event tests |
| Sampled key state cannot suppress or terminate normal edges | PASS | Polling and reconciliation removed; source matches 1.0.3 |
| Indicator stays visually continuous for 10+ seconds | PASS | Two 31-frame live observations over 12+ seconds |
| Pre-countdown ticks do not recreate the host | PASS | Countdown dedup plus stable hosting-view identity tests |
| Final-minute countdown changes remain visible | PASS | 60-to-59 publication and presentation mapping tests |
| Recording-to-transcribing preserves the host | PASS | Phase identity and panel hosting-view identity tests |
| Panel remains nonactivating and input-transparent | PASS | Direct AppKit panel lifecycle/configuration test |
| Manual menu recording remains operational | PASS | Debug and packaged 51+ second live recordings |
| Focused/full tests, build, and diff hygiene pass | PASS | Final clean `xcodebuild` test/build and `git diff --check` |
| Packaged artifact is Developer ID signed and notarized | BLOCKED | Local preview is Apple Development signed and non-notarized |
| No unrelated or iOS changes are included | PASS | Scoped macOS source/test/docs checkpoint paths only |

## Follow-Up

1. Produce and notarize a Developer ID artifact on the configured release lane
   only after explicit publication authorization.
2. Smoke that final artifact before replacing the public 1.0.4 download.
