# KBD-MVP-2 Physical Background-Session Feasibility QA

Date: 2026-07-14

Decision: **Passed**

This is the bounded KBD-MVP-2 feasibility spike. It is not the later signed-
device keyboard/Notes release matrix.

## Device, Commit, And Signing Boundary

- Repository branch: `master`
- KBD-MVP-1 checkpoint: `d5b2c0a` (`Complete KBD-MVP-1 settings action`)
- Spike implementation base: `50c43f3` (`Add keyboard dictation session
  controls and open-access support`)
- Final QA/spec/tooling checkpoint: the commit containing this record
- Physical device: Evgeny’s iPhone, iPhone 14 Pro Max (`iPhone15,3`)
- CoreDevice identifier: `DE70161A-3200-5D58-BF1E-DEA8B56FABC2`
- UDID: `00008120-001A19991E7BC01E`
- iOS: 26.5.2 (`23F84`)
- Trust/development state: paired, connected, Developer Mode enabled, developer
  disk image services available
- Development team: `PUA6HH22D7`
- Signing identity: Apple Development: Evgeny Potapenko (`V393ZF5XHL`),
  fingerprint `05FABF9B07D57B051E6210D633EB9BC5770BB419`
- App profile: `5a154c79-90f3-4800-b7f3-9c3f9e8fb66b`
- Extension profile: `a9a78ffb-9df8-42d7-85f5-ebfe8e7d571f`
- Bundle identifiers: `app.holdtype.HoldType.ios` and
  `app.holdtype.HoldType.ios.keyboard`
- Signed app and extension entitlement: both contain only the matching App
  Group `group.app.holdtype.HoldType.shared` for this bridge
- App background mode: `audio`
- Extension declaration: `RequestsOpenAccess = true`; the extension has no
  microphone purpose string and no recorder

The signed Debug app built, installed, and launched through CoreDevice. Both
embedded products were inspected after signing, not inferred from source-only
configuration.

## Approved Qualification Split

The physical iPhone owns the microphone and recorder lifecycle evidence. The
actual extension, command/state reduction, insertion, and restricted editing
evidence run only in Simulator, as required by the revised KBD-MVP-2 plan.

iPhone Mirroring was used only to inspect the containing-app controls. Starting
capture while Mirroring was connected produced the system message
`iPhone microphone is not available from Mac`, so Mirroring was disconnected
and was not used as microphone evidence. The physical recorder was then driven
directly by the signed DEBUG app route through CoreDevice. A wired QuickTime
screen preview did not render the orange microphone indicator, even while the
app logged confirmed recording; this visual observation is recorded as
unavailable rather than fabricated.

## Physical Containing-App Results

| Step | Expected | Actual |
| --- | --- | --- |
| Start bounded session | The containing app creates one explicit session with a 60-second deadline | Passed: the signed DEBUG route logged `session start`, published Ready, and started the bounded background assertion |
| Start real recording | `Listening…` is possible only after the app recorder returns success and reports active recording | Passed: `AVAudioRecorder.record(forDuration:)` returned true, `isRecording` was true, state publication succeeded, and the device log emitted `confirmed listening` |
| App owns microphone | No extension recorder or microphone permission exists | Passed: the only `AVAudioRecorder` is in `IOSKeyboardDictationSessionCoordinator`; the extension bundle has no microphone purpose string |
| Finish | Recording and the audio session stop before a result is ready | Passed: the device log emitted `finish stopped recording` and only then `deterministic result ready`; the temporary audio file was deleted and the audio session deactivated |
| Deterministic result | No live provider or network request runs | Passed: DEBUG published exactly `HoldType keyboard device probe`; no OpenAI or live-provider path ran |
| Cancel | Recording stops and no result is published | Passed in a separate signed-device run: `confirmed listening` followed by `cancel stopped without result` |
| Stop/lifetime | The session does not retain idle audio | Passed: Cancel ended the lifetime immediately; Finish stopped and deleted audio while the remaining bounded result window stayed non-recording; expiry remains capped at 60 seconds |

Representative physical console evidence:

```text
KBD-MVP-2 physical probe: session start
KBD-MVP-2 physical probe: confirmed listening
KBD-MVP-2 physical probe: finish stopped recording
KBD-MVP-2 physical probe: deterministic result ready
```

```text
KBD-MVP-2 physical probe: session start
KBD-MVP-2 physical probe: confirmed listening
KBD-MVP-2 physical probe: cancel stopped without result
```

## Simulator Keyboard Results

Simulator: iPhone 16, iOS 18.6 for the interactive extension pass; iPhone 17,
iOS 26.5 for focused tests.

- The real HoldType extension was presented in the containing app's standard
  Keyboard Practice field. The Simulator image does not include Apple Notes,
  so the plan-approved standard host field was used rather than claiming a
  Notes pass.
- With Full Access off, the actual extension showed `Enable Full Access`, kept
  Latest disabled, and retained the full Settings title. Evidence:
  [Simulator keyboard](assets/kbd-mvp-2-2026-07-14/simulator-full-access-off.jpeg).
- Computer Use tapped Period, Space, Delete, Return, and the system Globe on
  the real extension. The host field changed from the period and space, Delete
  removed the space, Return inserted a line break, and Globe switched to the
  English system keyboard.
- Focused tests used the real `KeyboardViewController` command and document-
  proxy paths to prove Full Access Start/Finish/Cancel, matching-request state
  reduction, one `UITextDocumentProxy.insertText` call for the deterministic
  result, no insertion for Cancel, stale/expired rejection, `Open HoldType`,
  and restricted editing.
- Layout tests proved Settings and Latest use intrinsic title width across
  320, 375, 393, and 430-point hosts without clipping.

Focused command:

```sh
xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS \
  -destination 'platform=iOS Simulator,id=6ACF3054-A7EA-4182-8D0D-996004730391' \
  test \
  -only-testing:HoldTypeIOSTests/KeyboardDictationBridgeTests \
  -only-testing:HoldTypeIOSTests/KeyboardViewControllerTests \
  -only-testing:HoldTypeIOSTests/KeyboardCommandSurfaceIOSTests \
  -only-testing:HoldTypeIOSTests/IOSVoicePlatformPlistTests \
  -only-testing:HoldTypeIOSTests/BrandStageKeyboardViewTests
```

Result: **34 tests in 5 suites passed**.

## Record Budget And Forbidden Mechanisms

- Exactly one extension-written current command file:
  `keyboard-dictation-command-v1.json`
- Exactly one app-written current state/result file:
  `keyboard-dictation-state-v1.json`
- Maximum record size: 4 KB
- Command lifetime: 5 seconds
- Session lifetime: 60 seconds
- No database, outbox, inbox, receipt, acknowledgement, lease, tombstone,
  retry queue, History redesign, provider request, private API, app launch from
  the keyboard, silent-audio keepalive, idle audio, or unbounded polling was
  added.

## Privacy And Energy Observations

- The containing app alone requested microphone permission and owned the audio
  session, recorder, and temporary file.
- The temporary `.m4a` was deleted on Finish, Cancel, failure, Stop, and expiry.
- No audio bytes, host text, API key, provider payload, or transcript content
  were logged. DEBUG logs contain only short lifecycle markers.
- The deterministic result is DEBUG-only and contains no captured speech.
- Mirroring disables the iPhone microphone in this environment and therefore
  cannot be used as recording proof. QuickTime preserved recording but did not
  expose the orange privacy indicator in its wired preview.
- Recording existed only between confirmed Start and Finish/Cancel. The audio
  session deactivated immediately afterward. No silent playback or idle
  recorder was retained.
- All waits and external commands were bounded. The app assertion expires at
  60 seconds; there is no retry or polling loop.

## Gate Result

KBD-MVP-2 is **Passed** under the approved physical-app/Simulator-keyboard
qualification split. KBD-MVP-3 may start from this feasibility result, but the
later signed-device keyboard/Notes host matrix remains mandatory before
TestFlight or release and must not reuse this split as release evidence.
