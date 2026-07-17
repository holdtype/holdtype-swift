# macOS 1.0.4 Regression Fix Plan

Status: source repair complete and physically verified from the current Xcode
build; production-artifact qualification remains separate.

## Goal

Restore the shipped macOS behavior that regressed in the 1.0.4 release
candidate:

- `Right Command` must start and stop one hold-to-record session reliably;
- the floating recording indicator must appear immediately and animate
  continuously without restarting once per second;
- manual menu recording must continue to work independently of the hotkey;
- the fix must restore the proven 1.0.3 hotkey event path without rolling back
  unrelated recording durability or iOS work.

The implementation goal was approved and started on 2026-07-17.

## Execution Status

Completed on 2026-07-17:

- the Right Command mapper and event-tap service now match the working 1.0.3
  implementation: real `flagsChanged` events are authoritative and there is no
  background modifier-key polling or reconciliation timer;
- unchanged countdown values and equivalent indicator presentations are
  suppressed;
- the indicator panel keeps one hosting view and changes animation identity
  only when it becomes visible again or changes phase;
- focused hotkey, countdown, coordinator, and panel-host tests pass;
- a strict acceptance audit additionally proves direct release exact-once
  behavior, one real runtime status delivery, stable panel/host identity across
  hide/show, non-key/non-main behavior, and input transparency;
- the full macOS test suite, macOS build, and `git diff --check` pass;
- debug and packaged menu recording both completed live transcription, and the
  recording indicator remained visible with continuous orbit motion for more
  than 12 seconds;
- a signed local 1.0.4 (5) preview DMG was built, mounted read-only, launched,
  and exercised through the real menu bar UI.
- after the hotkey rollback, the operator compiled the current source in Xcode
  and confirmed that a physical Right Command hold no longer releases itself;
- the post-audit focused tests, full macOS test target, macOS build, and fresh
  Apple Development preview build all pass.

Runtime correction discovered on 2026-07-17:

- a physical packaged-app hold reached the CGSession event tap and started
  recording, but the post-1.0.3 reconciliation timer synthesized `key_up` after
  0.09-0.35 seconds while the key was still physically held;
- a bounded probe confirmed that `CGEventSource.keyState` remained false for
  Right Command throughout the hold, so it is not a valid modifier-key signal
  on this machine;
- the user directed the repair back to the known-good 1.0.3 implementation
  instead of introducing another physical-state mechanism.

Remaining release gate:

- This Mac has an Apple Development identity but no Developer ID Application
  identity or notarization profile. GitHub Actions has the required production
  secret names configured, but the existing release workflow notarizes and
  publishes in one job. It was not triggered without explicit publication
  authorization. The local preview remains non-notarized and non-public.

Detailed evidence is recorded in
`docs/qa/macos/macos-1.0.4-regression-runtime-2026-07-17.md`.

## Confirmed Starting Evidence

The release candidate inspected during the investigation is
`HoldType 1.0.4 (5)`. Its signature, notarization, bundle identifier, and audio
input entitlement are valid. Input Monitoring was granted for the candidate.
The regression is therefore in application behavior rather than packaging or
TCC setup.

The first source boundary containing both failures is commit `3c242a7` (`Fix
dictation finalization and recovery`), followed by the 1.0.4 recording-duration
work. That commit mixes several independent macOS and iOS changes, so a broad
revert is unsafe.

Three causal chains are already established:

1. The hotkey mapper began requiring a separately sampled
   `CGEventSource.keyState(.combinedSessionState, ...)` value before accepting
   the `flagsChanged` key-down event. In the event-tap callback that snapshot can
   still describe the state before the event, so the real `Right Command`
   key-down is discarded.
2. The same post-1.0.3 change added a 150 ms reconciliation timer. On the
   affected machine both HID and session `CGEventSource.keyState` calls report
   Right Command as released while it is held, so two timer ticks synthesize an
   early key up and stop the recording.
3. The recording-duration monitor emits once per second. Before the countdown
   window it repeatedly assigns `nil` to `recordingCountdown`; that unchanged
   value is still published, the indicator coordinator updates, and the panel
   replaces its entire `NSHostingView`. `FloatingIndicatorView.onAppear` then
   restarts both infinite animations.

## Product Contract To Preserve

The existing specs remain authoritative; this is a regression repair, not a
new product behavior.

- `docs/specs/features/global-hotkey.md`
  - `Right Command` is a single-key hold-to-record shortcut.
  - Key down starts exactly one session and key up stops that session.
  - Repeated modifier events do not toggle the session.
- `docs/specs/features/floating-indicator.md`
  - The indicator is visible while recording when enabled.
  - Recording motion is subtle and continuous.
  - Countdown content changes once per second only during the final minute.
  - The panel does not activate HoldType, become key, or intercept input.
  - Indicator failure never disables the recording pipeline or menu controls.

The global-hotkey spec was restored to its 1.0.3 contract after physical runtime
evidence proved the later polling/reconciliation requirement unsafe.

## Scope And Non-goals

In scope:

- the `Right Command` event mapper and CGSession event-tap service;
- suppression of unchanged countdown/indicator updates;
- stable SwiftUI hosting inside the non-activating AppKit panel;
- focused unit tests, macOS build/test, bounded runtime smoke, and release
  artifact verification.

Out of scope:

- shortcut customization or a new shortcut;
- changing hold-to-record into toggle mode;
- redesigning the indicator;
- changing recording duration limits or warning thresholds;
- changing iOS recording, keyboard, History, or persistence behavior;
- reverting the full `3c242a7` commit;
- publishing or replacing the 1.0.4 artifact before all gates pass.

## Implementation Design

### 1. Restore the proven 1.0.3 Right Command path

Restore `RightCommandHotkeyEventMapper` and `CGEventGlobalHotkeyService` to the
working 1.0.3 event model while retaining only the later module import required
by the current source layout.

The intended state machine is:

1. Ignore non-`flagsChanged` events.
2. For a `Right Command` event while the mapper is logically released:
   - accept key down when the event's own flags contain Command;
   - capture the Option/translation intent from the same event;
   - mark the key logically pressed before emitting one `.keyDown`.
3. For a `Right Command` event while logically pressed:
   - release immediately when the event flags no longer contain Command;
   - treat another event with Command still present as a duplicate, not a
     toggle.
4. For non-Right-Command modifier events during an owned press, continue to
   merge the translation intent without changing press ownership.
5. Re-enable a disabled event tap as 1.0.3 did, without querying modifier state
   or synthesizing a key edge.
6. Do not create a polling timer, call `CGEventSource.keyState`, or introduce a
   replacement physical-state algorithm in this regression repair.

### 2. Publish countdown changes only when the value changes

At the controller boundary, notify `recordingCountdownDidChange` only when the
new `VoiceSessionCountdown?` differs from `oldValue`.

Expected effects:

- repeated `nil -> nil` duration ticks before the final minute stay internal;
- the runtime does not publish meaningless countdown updates;
- actual final-minute values still publish once per changed second;
- the transition from a countdown value to `nil` still publishes when recording
  stops or changes phase.

Add a second idempotence guard at the indicator coordinator: compute the next
`FloatingIndicatorPresentation?` and do not call the presenter when it is equal
to the last delivered presentation. This protects the AppKit boundary from
duplicate status, settings, or future publisher emissions even if an upstream
source becomes noisy again.

### 3. Keep one hosting tree for the panel lifetime

Refactor `FloatingIndicatorPanelController` so `update(with:)` does not replace
`panel.contentView`.

Use this ownership boundary:

- the controller owns one `NSPanel`;
- the controller owns one observable hosting model containing the current
  non-optional `FloatingIndicatorPresentation`;
- the controller creates one `NSHostingView` with a small SwiftUI host view;
- later updates mutate the hosting model on the main actor;
- `hide()` only orders the panel out; it does not destroy or replace the hosting
  tree.

SwiftUI remains the source of truth for visual state. AppKit only owns panel
lifecycle, placement, focus behavior, and the stable host.

Animation identity may change only when the visible session starts again or the
phase changes between recording and transcribing. Countdown changes and
equivalent presentation updates must retain the same `FloatingIndicatorView`
identity, so its `@State` animations do not restart.

The refactor must retain all current panel properties:

- `.borderless` and `.nonactivatingPanel`;
- `canBecomeKey == false` and `canBecomeMain == false`;
- `ignoresMouseEvents == true`;
- floating level, all-spaces/full-screen behavior, clear background, and
  existing size/placement.

## Planned File Ownership

Expected implementation paths:

- `HoldType/Services/CGEventGlobalHotkeyService.swift`
- `HoldTypeTests/GlobalHotkeyServiceTests.swift`
- `HoldType/Services/DictationSessionController.swift`
- `HoldType/Services/FloatingIndicatorCoordinator.swift`
- `HoldType/FloatingIndicatorPanelController.swift`
- `HoldType/FloatingIndicatorView.swift` only if a narrow phase/session identity
  hook is required
- `HoldTypeTests/DictationSessionControllerTests.swift`
- `HoldTypeTests/FloatingIndicatorPresentationTests.swift`
- a new focused panel-host lifecycle test file if that keeps AppKit assertions
  isolated
- a dated report under `docs/qa/macos/` for the final runtime evidence

The current worktree contains unrelated in-progress recording durability edits,
including edits in `DictationSessionController.swift` and its tests. The fix
must preserve them. If those two dirty files need a small change, implementation
must stage only the regression-fix hunks rather than the full file. All other
task paths must also be reviewed for concurrent changes immediately before
staging.

## Test Plan

### Hotkey mapper tests

Add deterministic coverage for:

1. key down is emitted from the Right Command `flagsChanged` event when its
   flags contain Command;
2. key up is emitted from the matching event when its flags clear Command;
3. repeated Right Command `flagsChanged` while Command remains present is
   ignored;
4. repeated key up is ignored;
5. Option-before, Option-during, and Option-release translation intent behavior
   remains unchanged.

The mapper has no separately injected physical state. Its signature and
behavior intentionally match the working 1.0.3 implementation.

### Countdown and coordinator tests

Add coverage for:

1. repeated elapsed seconds before the countdown window do not notify a
   `nil -> nil` countdown change;
2. entering the final minute publishes the first countdown;
3. each changed countdown second publishes once;
4. stopping clears a visible countdown exactly once;
5. multiple equivalent runtime/coordinator emissions result in one presenter
   update;
6. a real phase or countdown change still reaches the presenter.

### Panel-host lifecycle tests

Add a focused main-actor AppKit test or an equivalent injectable seam proving:

1. the first visible presentation creates the host;
2. an equivalent update and a countdown-only update keep the same hosting-view
   identity;
3. a recording-to-transcribing change updates content without replacing the
   hosting view;
4. hide/show does not make the panel key or main;
5. the panel continues to ignore mouse events.

Avoid assertions against animation timing in unit tests. Stable host identity
and deduplicated updates are the deterministic regression assertions; visual
continuity belongs to runtime smoke.

## Execution Phases And Gates

### Phase A: Baseline and collision check

1. Confirm the branch is still `master`.
2. Capture `git status --short` and task-path diffs.
3. Re-read any concurrent edits in the planned files.
4. Run the focused existing hotkey and indicator tests before edits when the
   current worktree builds.
5. Do not reset, stash, clean, or include unrelated changes.

Gate: the implementation agent can identify which exact hunks belong to this
fix and which belong to existing recording durability work.

### Phase B: Hotkey repair

1. Restore the 1.0.3 mapper and event-tap service path.
2. Remove the physical-state provider, timer, and recovery-only tests.
3. Run only `GlobalHotkeyServiceTests`.

Gate: direct, repeated, and translated press/release tests pass and the service
contains no background modifier polling.

### Phase C: Indicator repair

1. Suppress unchanged controller countdown notifications.
2. Deduplicate coordinator presentations.
3. Introduce the stable hosting model/view and stop replacing content views.
4. Add countdown, coordinator, and AppKit lifecycle regression tests.
5. Run the focused indicator and duration-monitor/controller tests.

Gate: equivalent per-second ticks do not reach the presenter, countdown changes
do reach it, and host identity remains stable.

### Phase D: Full macOS verification

Run:

```sh
xcodebuild \
  -project HoldType.xcodeproj \
  -scheme HoldType \
  -destination 'platform=macOS' \
  test

xcodebuild \
  -project HoldType.xcodeproj \
  -scheme HoldType \
  -destination 'platform=macOS' \
  build

git diff --check
```

The full test run validates the combined current worktree, including unrelated
in-progress durability changes, but the checkpoint must still include only
task-owned hunks.

Gate: tests, build, and diff hygiene all pass with no iOS source changes caused
by this task.

### Phase E: Bounded macOS runtime smoke

Because this changes a real global hotkey and visible AppKit panel, runtime QA
is required.

1. Start a scoped `caffeinate` guard before the first UI/runtime action.
2. Launch the freshly built app through `script/build_and_run.sh --verify` so
   automated QA uses the repository's sanitized Keychain environment.
3. Confirm the app reports a registered Right Command shortcut and the menu
   remains usable.
4. Exercise a Right Command press/release through an available automation
   surface that produces the actual event-tap path.
5. Verify one key down starts recording, the indicator appears, one key up stops
   recording, and no duplicate session is created.
6. Keep a recording indicator visible for at least 10 seconds before the
   countdown window. Capture video or timestamped observations showing that its
   pulse/orbit does not reset once per second.
7. Exercise manual menu start/stop as the independent fallback.
8. Verify the panel does not become key/main, steal focus, or accept mouse
   input.
9. Inspect compact hotkey/runtime logs for one press and one release; do not log
   dictated text, audio paths, credentials, or provider payloads.
10. Stop the scoped `caffeinate` process when the smoke ends.

If Computer Use or the automation surface cannot generate a distinguishable
Right Command hardware edge, report that portion as blocked rather than calling
synthetic generic Command proof. Unit tests and a menu-only smoke do not replace
the real hotkey gate.

Gate: runtime QA is reported as `required` and passed, or explicitly `blocked`
with the last successful build/test evidence. A blocked real-hotkey smoke means
the release artifact is not yet publishable.

### Phase F: Release artifact qualification

After source/runtime gates pass:

1. Build the normal Release archive/package without changing the version solely
   for local qualification.
2. Verify the produced `.app`/DMG rather than only Xcode build settings.
3. Check bundle version/build number, Developer ID signature, notarization,
   bundle identifier, hardened runtime, and audio-input entitlement.
4. Mount the DMG read-only and run the same bounded hotkey/indicator smoke from
   the packaged app when TCC identity permits it.
5. Record exact artifact path, checksum, commands, and outcomes in the macOS QA
   report.

Gate: only a packaged artifact that passes signature/entitlement checks and the
real hotkey plus stable-indicator smoke is eligible to replace the broken 1.0.4
candidate.

## Acceptance Criteria

The implementation goal is complete only when all of the following are true:

- a real Right Command press starts recording in the fixed build;
- releasing it stops the same session exactly once;
- repeated event edges cannot toggle or duplicate the normal key down/up path;
- the indicator appears when enabled and remains visually continuous for at
  least 10 seconds;
- pre-countdown one-second ticks do not recreate the host or restart animation;
- final-minute countdown changes remain visible once per second;
- recording-to-transcribing changes the indicator phase without replacing the
  hosting view;
- the panel remains non-activating and input-transparent;
- manual menu recording remains operational;
- focused tests, the full macOS test suite, macOS build, and `git diff --check`
  pass;
- the packaged artifact retains the required identity, signing, notarization,
  and audio-input entitlement;
- no unrelated dirty changes or iOS changes are included in the fix checkpoint.

## Checkpoint And Rollback Strategy

This planning document is committed separately before implementation.

The later implementation should use one scoped checkpoint commit on `master`
after all verification gates pass. Stage only task-owned paths and, for already
dirty files, only task-owned hunks. Do not create a branch, rewrite history, or
force-push.

If the runtime smoke exposes an unresolved hotkey edge case, stop publication
and revert only the narrow unverified fix hunks. Do not restore the broken 1.0.4
candidate and do not revert the full mixed recovery commit.

## Goal Start Instruction

Once this plan is approved, create a goal with this objective:

> Implement and qualify the macOS 1.0.4 regression repair defined in
> `docs/macos-1.0.4-regression-fix-plan.md`, preserving unrelated worktree
> changes and completing every acceptance gate before marking the goal done.

The goal should reference this file as its execution contract. No token budget
is required unless the user specifies one at goal start.
