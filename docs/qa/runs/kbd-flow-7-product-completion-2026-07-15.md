# KBD-FLOW-7 Product Completion — 2026-07-15

## Scope

This checkpoint removes the retired manual-session presentation from the iOS
keyboard and reconciles the governing iOS keyboard specs with the approved
microphone-first handoff. It does not change the macOS app or ordinary
standalone Voice behavior.

## Verified Contract

- The central Voice indicator remains the keyboard entry point in Ready,
  Opening, Starting, Listening, Processing, and compact failure states.
- The keyboard contains no `Session not running`, `Start a voice session`,
  written `Open HoldType` route, or other manual-navigation presentation.
- Full Access and other setup blockers keep the indicator visible; tapping it
  uses the existing bounded launch and targeted containing-app recovery path.
- The retired recovery and separate progress view trees are removed rather
  than hidden behind unused branches.
- Keyboard status and accessibility values remain short operational labels.
- The special containing-app keyboard-session diagnostic remains available for
  bounded physical qualification, but it is not a production keyboard entry
  point.
- The handoff, keyboard experience, guided recovery, and iOS release specs now
  describe the same microphone-first flow and two-projection delivery contract.

## Automated Evidence

The final focused iOS Simulator verification covered only the changed keyboard
surface:

- `BrandStageKeyboardViewTests`: 15 passed;
- `KeyboardCommandSurfaceIOSTests`: 7 passed.

The production-source search found none of the retired presentation types,
identifiers, or user-facing manual-session strings in `HoldTypeKeyboard` or
`KeyboardShared`.

## Scope Boundary

- No file under `HoldType/`, `HoldTypeTests/`, `HoldTypeUITests/`, or a macOS
  package was changed.
- No macOS build or macOS test was run for this checkpoint.
- Ordinary Voice, Draft, Rules, History, Usage, Settings, and their tests were
  not changed in this checkpoint.
- The unrelated working-tree change in
  `HoldType.xcodeproj/project.pbxproj` is excluded from this checkpoint.
- Signed-device and TestFlight qualification remain KBD-FLOW-8.
