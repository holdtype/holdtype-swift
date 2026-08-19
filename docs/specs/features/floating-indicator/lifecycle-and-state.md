# Floating Indicator Lifecycle and State

- Node type: leaf
- Contract ID: `holdtype.macos.floating-indicator.lifecycle`
- Domain ID: `holdtype.macos.floating-indicator`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.floating-indicator.lifecycle@1`
- Read when: state mapping, visibility, failure, focus, or lifecycle ownership is in scope.
- Do not read when: only visual styling or countdown appearance is in scope.
- Maximum size: 100 physical lines.

## State mapping

| App state | Visibility | Display |
| --- | --- | --- |
| `idle` | hidden | none |
| `recording` | visible when enabled | compact cyan recording indicator |
| `recording, final 15 seconds` | visible when enabled | countdown; yellow orbit for final 10 seconds |
| `transcribing` | visible when enabled | compact purple waiting indicator |
| `done` | hidden | none |
| `error` | hidden | none |

- Cancel, pre-capture failure, success, and post-transcription-start failure
  hide the indicator immediately.
- A quick next recording displays fresh recording state without stale
  completion or error.
- Recording-to-transcribing may switch visuals without exposing transcript text.
- Setup or permission failure before capture may leave it hidden while menu or
  Settings remains authoritative.
- Disabling `showFloatingIndicator` prevents presentation but changes no other
  product behavior.

## Failure and interaction safety

- Failure to create or show the indicator does not stop the session; menu
  status provides feedback.
- After transcribing-state failure, the indicator hides before a blocking
  recovery prompt accepts input, so the first Try Again click retries
  transcription rather than dismissing stale indicator UI.
- The indicator does not steal focus, activate HoldType, or intercept input.

## Ownership

- A long-lived runtime coordinator, not transient menu content, owns lifecycle
  so the surface remains stable while the menu opens, closes, or re-renders.
- `showFloatingIndicator` is local UserDefaults-backed state.
- Appearance selection changes no recording, transcription, output, clipboard,
  Settings, or permission state.

## Verification mapping

- Verify state-to-visibility mapping and that terminal failure hides the
  indicator before prompt interaction.
- Runtime smoke verifies recording visibility and no focus theft.
- Verify disablement leaves menu and session behavior intact.
- Countdown coverage verifies start at 15, orbit change at 10, and updates that
  do not restart animation.

## Dependencies

- [Floating indicator](../floating-indicator.md) — shared scope and invariants.
- [Menu bar shell](../menu-bar-app-shell.md) — fallback state presentation.
