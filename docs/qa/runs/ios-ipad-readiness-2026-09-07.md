# iPad readiness check — 2026-09-07

## Result and scope

The current iOS app and embedded keyboard build for Simulator and a signed
physical iPad after two compatibility fixes. This is not iPad release
qualification. Physical launch, recording, keyboard handoff/delivery, and
compact-window interaction remain unverified.

Baseline: `0bd32c87` on `master`; implementation is the checkpoint containing
this report. No branch, worktree, publication, or live OpenAI request was used.

## Contract basis and changes

Traversal: `docs/specs/README.md` → `index.md` → `features/ios-v1-release.md`
→ scope, navigation, release gates; `platform-testing-strategy.md` → iOS
evidence/task matrix; `verification-strategy.md` → invariants and evidence.
The compilation failures additionally selected `text-fixes.md` → catalog,
iOS Voice/keyboard, privacy/failure, and the writing-skill compatibility clause.
Voice editing observations used `ios-voice-draft.md` → editing/recovery.

Pinned basis: iOS release/scope/navigation/gates `@1`, platform testing and
verification `@1`, Text Fixes `@3`, writing skill `@1`, Voice Draft editing and
recovery `@1`. Unrelated macOS features, persistence redesign, release promotion,
floating keyboard, Stage Manager qualification, and hardware shortcuts excluded.

Mode: Restore. User approved compilation repair and iPad verification.

- The shared transformation error enum acquired `writingSkillUnavailable` and
  `writingSkillContainerExpired`; the iOS exhaustive switch omitted them.
  Map both to the existing provider-unavailable failure, preserving voice state.
  Writing Skill remains excluded from iOS.
- The iOS Fixes editor still called the removed `restoringDefaults()` API.
  `TF.CATALOG` already says there is no Restore Defaults. Remove the stale
  button, confirmation state/dialog, model method, and obsolete test assertions.
  Preserve add/edit/toggle/reorder/delete and failed-save behavior.
- No product contract changes. Production Swift: +2/−38 lines; tests: +37/−7.

## Automated and bundle evidence

| Check | Result |
| --- | --- |
| Swift structure gate and `git diff --check` | Passed |
| `HoldType-iOS` Debug, iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Passed |
| `HoldType-iOS` Debug, connected iPad Pro 13-inch (M5), iPadOS 26.6.1 | Passed with automatic development signing |
| `HoldType` macOS baseline build | Passed |
| `IOSForegroundVoiceTextFixProcessorTests`, package test | 5 tests passed; new parameterized test exercised both errors, one provider call, unchanged Pending/Latest |
| `IOSTextFixEditorModelTests`, Debug-Tests on iPad Simulator | 7 tests passed |
| Ordinary app products after tests | Embedded keyboard present; no `.xctest` payload; device family `[1, 2]` |
| Signed app/keyboard entitlements | Same configured team and `group.app.holdtype.HoldType.shared`; microphone purpose string only in app |

The first package-test run passed the new cases but an existing fixture threw
`localPersistence` in the oversized/whitespace test. One unchanged rerun passed
all five tests; the transient fixture failure was not diagnosed further.

Semantic assist used the successful iOS build's Index Store to audit only
`IOSTextFixEditorView.swift`: indexed resolution, no ownership violations,
duplicated sources of truth, or manual synchronization edges. The one inferred
derived-state finding concerns existing `newActionIdentifier` rotation after a
save, outside this removal. No semantic baseline or watcher was created.

## Simulator interaction evidence

Computer Use operated the actual app on iPad Pro 13-inch (M5), iOS 26.5,
with `HOLDTYPE_AUTOMATION=1` (live Keychain disabled), light appearance.
The normal Debug product was reinstalled after hosted tests.

| Starting state and action | Observed result |
| --- | --- |
| Cold launch, portrait | Voice and sidebar render; Voice reaches Ready |
| Select Rules → Fixes | Two built-ins and six custom Fixes visible; no Restore Defaults control or explanatory section |
| Select History | Honest empty state, no placeholder or crash |
| Select Usage | Empty estimate and disabled Reset render |
| Select Settings, open Keyboard & Full Access | Settings sections, setup status, and practice field render |
| Rotate Settings to landscape | Sidebar and settings content remain visible and usable |
| Edit Voice Draft, leave and relaunch | Entered sample text remains in Draft; editing disables dictation and normal Ready returns after relaunch |
| Enable extension in Simulator Settings | HoldType appears in the keyboard list; Full Access observed off |
| Focus app's standard practice field | System keyboard appears in the actual editable host |

The actual HoldType extension was not successfully selected: available Computer
Use APIs lack a long-press duration, Globe taps toggled recent system keyboards,
and the fallback runtime snapshot omitted a target for Globe. Simulator window
targeting also became unstable when another existing Simulator window became
foreground. No custom-keyboard insertion result is claimed.

Two attempts to drag the iPad resize handle did not resize the app, despite
Windowed Apps being selected in Simulator Settings. This is incomplete compact
QA, not evidence of an app layout defect. Computer Use frames were observation
only; no screenshot assets were retained.

## Physical-device lane and remaining work

The signed app installed successfully over USB. Sanitized launch failed with
CoreDevice 10002 / FBS `Locked`: the device could not be unlocked. The user was
asked to unlock it. No run-owned HoldType process remained on that device.

Before claiming iPad support ready: complete unlocked-device launch and visual
smoke; compact-window interaction; actual extension editing/Globe in portrait
and landscape; and signed microphone → app handoff → host insertion with the
required Full Access, interruption, privacy, and energy checks. Live-provider
qualification still needs explicit authorization and operator-supplied setup.

Minor observed adaptation residuals: Usage explanatory text says “this iPhone”;
keyboard setup says “In iPhone Settings.” These were not changed in this repair.

Cleanup: stop run-owned app and iPad Simulator, release idle guard, remove
temporary build/test/semantic output; preserve the pre-existing iPhone Simulator
and installed physical iPad app. No unrelated repository edits were present.
