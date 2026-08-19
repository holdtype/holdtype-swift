# Menu Bar Primary Controls

- Node type: leaf
- Contract ID: `holdtype.macos.menu-bar-shell.controls`
- Domain ID: `holdtype.macos.menu-bar-shell`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.menu-bar-shell.controls@1`
- Read when: menu commands, ordering, shortcut hints, availability, or setup routing is in scope.
- Do not read when: only process/Dock lifecycle or compact error status is in scope.
- Maximum size: 100 physical lines.

## Command structure

- The top block shows the app title and current compact status.
- The primary row is `Transcribe` when recording may start and may become
  `Stop Recording` while a menu-started recording is active.
- `Transcribe & Translate` is separate and disabled when translation is
  disabled or not fully configured.
- `Paste Last Result` inserts the last saved accepted transcript and is
  disabled when retention is off or no result exists.
- Normal transcription, translation transcription, and Paste Last Result each
  show their global shortcut hint in a separate right-aligned column while the
  command label remains left-aligned. Settings and Quit need no hint.
- The menu includes `Manage Fixes…`, Transcript History, Settings, and Quit.
  Manage Fixes opens the normal editor and never treats a HoldType editor field
  as an external transformation target.
- There is no actionable `Fixes…` palette fallback; the palette is invoked only
  through its global shortcut.
- There is no standalone Last Transcript row or Save Last Transcript action.
- Manual update checks live in Settings, not the compact popover.

## Ordering and development utility

- The three primary dictation/paste commands precede `Manage Fixes…`.
- `DV-MENU-1`: Current development builds include `Dev Vlogs…`; it dismisses
  the menu,
  activates HoldType as needed, and opens the normal SwiftUI Dev Vlogs window
  without requesting Camera, starting preview, or starting capture.
- `DV-MENU-1A`: HoldType `1.0.11` does not expose `Dev Vlogs…`, independently
  of Dev Vlogs acceptance. Its post-release restoration in development source
  does not authorize a later public shipping claim; that remains an explicit
  release decision.
- `DV-MENU-2`: The item preserves compactness, existing commands, shortcut
  hints, disabled states, ordering, and recovery. Camera, destination,
  app-policy, library, and build controls remain in the dedicated window.
- `DV-MENU-2A`: In development builds it follows Manage Fixes, Transcript
  History, and Settings and is the last utility item before the Quit divider.
- `DV-MENU-3`: A compact capturing or degraded indication requires a truthful
  later shipping-state owner. Phase 1 Off/Setup does not require or synthesize
  it from incomplete setup or Phase 0B evidence.

## Setup and permissions

- The menu has no permission checklist or recovery block; detailed recovery is
  owned by full Settings.
- Choosing Transcribe with required setup incomplete keeps recording inactive
  and opens Settings focused on the relevant setup section.
- Accessibility does not block transcription or Last Result saves unless the
  enabled output or context behavior requires active-app control.
- Missing Input Monitoring does not block menu-driven recording; its detailed
  status belongs in Settings and shortcut-specific recovery that needs it.
- Before recording exists, Transcribe may be a clearly labelled unavailable
  placeholder. A placeholder Transcribe/Stop binding may be exercised only if
  it clearly says microphone input is not captured in that build.

## Failure policy

- A Transcribe action during active recording never creates a parallel capture.
- During transcription, recording actions are disabled or ignored with
  understandable feedback.

## Dependencies

- [Menu bar app shell](../menu-bar-app-shell.md) — shared scope and invariants.
- [Microphone input](../microphone-text-input.md) — capture availability.
- [Privacy and permissions](../privacy-and-permissions.md) — setup ownership.
- [Text output](../text-output-workflow.md) — Last Result behavior.
- [Dev Vlogs](../dev-vlogs.md) — utility-window scope and shipping gate.
- [Text Fixes](../text-fixes.md) — Fixes editor and palette ownership.
