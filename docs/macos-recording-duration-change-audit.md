# macOS Recording Duration Change Audit

Date: 2026-07-17
Baseline: `v1.0.3`
Primary commits: `3c242a7` and `efdf660`

## Question

Identify which changes were actually required to let a user select the maximum
recording duration, which unrelated changes caused the macOS 1.0.4 regressions,
and which larger additions should remain until they can be simplified without
risking recorded audio.

## Scale And Boundary

`3c242a7` (`Fix dictation finalization and recovery`) changed 95 files with
17,200 insertions and 1,206 deletions. It rewrote macOS hotkey handling,
indicator updates, recorder finalization, the session controller, History and
recovery, and substantial iOS recording/persistence code.

`efdf660` (`Add configurable recording duration limits`) then changed 61 files
with 1,577 insertions and 400 deletions. The user-facing requirement was much
narrower: store a 1-15 minute selection, pass that limit into the next recording,
show the final-minute countdown, and finish once at the selected limit.

The two commits must not be reverted as one block. Later recording-durability
work now depends on their recovery types and persistence boundaries, while the
proven regressions are isolated.

## Findings And Decisions

| Area | Required for selectable duration | Audit result | Decision |
| --- | --- | --- | --- |
| Settings picker and persistence | Yes | Bounded whole-minute value, clamped migration, next-recording semantics | Keep |
| Shared `RecordingDurationLimit` and warning schedule | Yes | 1-15 minutes, default 5, final-minute milestones are deterministic and tested | Keep |
| Recorder receives the selected maximum | Yes | Each attempt freezes its own selected value and `AVAudioRecorder` receives it | Keep |
| Controller duration monitor and automatic Finish | Yes | Exact-once race handling is substantially larger than the original request but protects the retained limit-length artifact | Keep for this repair |
| Global Right Command service | No | `3c242a7` added `CGEventSource.keyState` and a 150 ms timer; physical testing proved the modifier reads released while Right Command is held, causing a synthetic stop after 0.09-0.35 seconds | Restore the exact `v1.0.3` event path |
| Floating indicator host lifecycle | Countdown only | Per-second `nil` publications and `NSHostingView` replacement restarted animation continuously | Keep countdown; deduplicate publications and retain one host |
| Minimum recording duration | No | The 0.3 second guard remained as an initializer parameter but was ignored, so accidental taps could reach OpenAI | Restore provider rejection for reliably measured short recordings; preserve positive-byte audio for local recovery |
| Durable processing checkpoint and saved-recording History | No, but protects long recordings | Large product expansion beyond the original setting; no current regression found, and later durability commits depend on it | Keep; simplify only as a separate spec and migration task |
| Finalized-media probe and exact-once finalization | Auto-Finish support | Complex, but bounded to two seconds and covered for delegate/key-up/watchdog races | Keep |
| Private-route warning cues | Optional warning UX | Avoids feeding warning sounds into the microphone; no regression found | Keep |
| Menu countdown presentation | Yes for visible warning | Pure presentation mapping; no regression found | Keep |
| iOS/shared persistence changes | Not required for the macOS setting alone | They implement the same portable limit and durable iOS workflow; Domain, OpenAI, iOSCore, and Persistence package suites pass | Do not roll back from the macOS repair |

## Proven Regression Repairs

### Right Command

The current service is restored to the `v1.0.3` implementation except for the
module import required by the current source layout:

- listen for `flagsChanged` on the CGSession event tap;
- require the `kVK_RightCommand` key code;
- emit key down when the event flags contain Command;
- emit key up when the event flags clear Command;
- do not poll `CGEventSource.keyState`;
- do not run a reconciliation timer.

The bounded hardware probe used during diagnosis showed both HID and session
`keyState` remaining false while the modifier was held. The HID right-command
modifier flag did track the hardware, but the repair deliberately does not add
a new state algorithm because the known-good event implementation is sufficient.

### Floating Indicator

The countdown feature remains. The regression repair suppresses unchanged
countdowns and equivalent presentations, while the AppKit panel owns one
hosting view for its lifetime. Countdown and phase changes update the model
without replacing the SwiftUI tree.

### Too-Short Recordings

The recorder again rejects a reliably measured recording shorter than the
configured 0.3 second minimum before provider work. Unlike 1.0.3, a positive-byte
artifact is not silently deleted; the current durability path may retain it as
a local recovery item. A zero or unavailable duration is not treated as proof
that recorded bytes are disposable.

## Larger Changes Kept Deliberately

The durable recovery implementation is disproportionate to a settings picker,
but removing it in this release repair would require a separate data migration
and would reopen loss windows around automatic Finish, provider dispatch, app
termination, and relaunch. It is classified as architectural overreach, not as
a demonstrated 1.0.4 runtime regression.

A later simplification should start from a new product decision about whether
limit-length recordings must survive relaunch. It must not be attempted as a
mechanical revert of `3c242a7`.

## Verification Gates

- focused GlobalHotkeyService tests;
- focused AudioRecorderService tests, including restored too-short rejection;
- AppSettings and shared duration-domain tests;
- full macOS test and build;
- shared Domain, OpenAI, iOSCore, and Persistence package suites;
- physical packaged Right Command hold longer than 10 seconds followed by one
  release;
- continuous indicator observation during that hold;
- Developer ID signature, notarization, entitlement, and packaged runtime smoke
  before release eligibility.

## Verification Result

The focused AppSettings, recorder, controller, hotkey, and indicator tests pass.
The full macOS test target and macOS build pass, as do the Domain, OpenAI,
iOSCore, and Persistence package suites. The operator compiled the repaired
source in Xcode and confirmed with a physical Right Command hold that the
premature release regression is gone.

A fresh Apple Development preview was also produced successfully as
`HoldType 1.0.4 (5)`. It is a non-notarized local artifact; no public release
workflow was triggered.
