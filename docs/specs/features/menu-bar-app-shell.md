# Menu Bar App Shell

- Node type: hybrid
- Contract ID: `holdtype.macos.menu-bar-shell`
- Domain ID: `holdtype.macos.menu-bar-shell`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.menu-bar-shell@1`
- Read when: menu bar lifecycle, commands, compact app state, status, recovery, or quit behavior is in scope.
- Do not read when: only recording, transcription, output, or a linked utility surface is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

HoldType is a small native macOS menu bar dictation utility. The menu bar item
is its primary persistent presence, exposes core dictation actions, and shows
recording or transcription status without requiring a document-style window.

This contract covers menu bar presence, core menu items, Settings entry,
compact output status, ready/recording/transcribing/error presentation,
app-shell prompts, optional floating-indicator routing, software-update command
placement, and the development-only Dev Vlogs utility entry.

## Non-goals

- Final visual design.
- App Store packaging or notarization.
- Accounts, billing, cloud sync, analytics, telemetry, or server-side app state.
- Electron, React, Node.js, WebView UI, Tauri, or Rust for the first MVP.
- OpenWhispr's Electron tray asset lookup, icon fallback generation, or
  cross-platform tray behavior.

## Children

- [Lifecycle and presentation](menu-bar-app-shell/lifecycle.md) — process and
  Dock presence, menu-surface behavior, window presentation, and quitting.
- [Primary controls](menu-bar-app-shell/primary-controls.md) — command rows,
  ordering, shortcut hints, disabled states, and setup routing.
- [State, status, and recovery](menu-bar-app-shell/state-and-status.md) — app
  states, compact status, error recovery, and independent surface state.

## Shared invariants

- Menu state accurately reflects recording and transcribing state.
- Errors are visible in menu status, Settings, or an optional notification.
- Linked feature surfaces keep their own contracts and state ownership.
- Migration does not broaden Dev Vlogs shipping scope or change any linked
  permission, recording, output, update, Fixes, History, or indicator behavior.

## Dependencies

- [Microphone input](microphone-text-input.md) — recording availability and capture behavior.
- [Privacy and permissions](privacy-and-permissions.md) — permission gates and recovery ownership.
- [Text output](text-output-workflow.md) — accepted transcript and Last Result behavior.
- [Floating indicator](floating-indicator.md) — detailed indicator lifecycle.
- [Software updates](software-updates.md) — updater relaunch and manual checks.
- [Dev Vlogs](dev-vlogs.md) — development-only utility and shipping activation.
- [Text Fixes](text-fixes.md) — editor and palette ownership.
- [Transcript History](transcript-history.md) — history ownership and recovery.

## Verification mapping

Verify menu presence, Transcribe/Stop transitions, disabled states, window
opening, quit, compact status, and absence of transcript or successful-output
text when the applicable implementation checkpoint is tested.

## Unknowns

- A future product-naming decision may replace `HoldType` before packaging.
