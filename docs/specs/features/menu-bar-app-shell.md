# Menu Bar App Shell

## Goal

Define the first app-shell contract for HoldType as a small native macOS menu
bar dictation utility.

The app should be available from the menu bar, expose core dictation actions,
and show recording/transcribing status without requiring a full document-style
window.

## Scope

This spec covers:

- menu bar presence
- core menu items
- settings window entry point
- compact output status
- basic ready/recording/transcribing/error status
- floating indicator as an optional MVP polish surface
- quit confirmation for accidental app termination
- software update command placement

## Non-goals

- final visual design
- App Store packaging or notarization
- account, billing, cloud sync, or telemetry surfaces

## User-visible behavior

- The app should run as a macOS menu bar app.
- The menu bar status item should remain available while the app is running.
- The menu bar item identity for the MVP is the title `HoldType`, the native
  SF Symbol `mic.fill`, and help text `HoldType Dictation`.
- The menu bar title is the accessibility label. The help text is the tooltip
  when the SwiftUI `MenuBarExtra` label exposes native macOS help.
- The top menu block should include the app title and current compact status.
- The app should not copy OpenWhispr's Electron tray asset lookup, icon
  fallback generation, or cross-platform tray behavior.
- The menu should include `Transcribe` when recording can be started from the
  menu. If a recording is already active, the same primary position may become
  `Stop Recording` so menu-started recordings have an explicit stop action.
- The three primary command rows must visibly include their global shortcut
  hints: normal transcription, translation transcription, and Paste Last
  Result. The command label should stay left-aligned and the shortcut hint
  should appear as a separate right-aligned column, matching normal macOS menu
  scanning. Settings and Quit do not need shortcut hints in this popover.
- The menu should include `Transcribe & Translate` as a separate action for the
  translation-mode recording shortcut. It should be disabled when translation
  is disabled or not fully configured in Settings.
- The menu should include `Paste Last Result` for inserting the last saved
  accepted transcript into the active app. It should be disabled when the
  setting that keeps the last result is off or no last result is available.
- After the three primary dictation and paste commands, the menu should include
  `Fixes…` with the `⌥J` hint. It captures the last valid non-HoldType external
  target before opening the palette and is disabled when no compatible target
  can be captured.
- The menu should include `Edit Fixes…` after `Fixes…`. It opens the normal
  Fixes editor and never treats a HoldType-owned editor field as the external
  transformation target.
- The menu should not show a separate permission checklist or permission
  recovery block. Required permission recovery belongs in full Settings.
- If the user chooses Transcribe while required setup is incomplete,
  recording must remain inactive and the app should open Settings focused on the
  relevant setup section.
- Accessibility permission must not block transcription or Last Result saves
  unless the enabled output or context behavior requires active-app
  control. Detailed Accessibility recovery belongs in the permission setup and
  Settings surfaces.
- Missing Input Monitoring must not block menu-driven recording. Detailed Input
  Monitoring status belongs in full Settings and any shortcut-specific recovery
  flow that needs it.
- Before recording exists, Transcribe may be a visible placeholder,
  but it must clearly state that recording is not available yet.
- Before recording exists, a placeholder Transcribe/Stop transition may exercise
  the menu binding, but it must clearly state that microphone input is not
  captured in that build.
- The menu should include Transcript History, Settings, and Quit.
- Manual software update checks belong in Settings rather than the compact menu
  bar popover.
- The menu should not include a standalone Last Transcript text row or a Save
  Last Transcript action.
- After a completed recording fails during transcription, the app should show a
  frontmost recovery prompt that explains the failure and offers only the
  applicable actions: Try Again, Open OpenAI Settings, Open Transcription
  Settings, or Dismiss.
- The menu should also show one compact status line such as
  `Error: Timed out`, plus the same compact recovery actions when the user
  opens the menu after the prompt.
- The menu recovery block must not auto-open Settings or Transcript History.
  Navigation happens only after the user chooses an action.
- The menu recovery block should not include a Transcript History shortcut.
  Transcript History remains available from the normal menu item.
- Dynamic menu text must stay compact. The menu must not place long diagnostic
  text, dictated transcript text, or successful output status messages into menu
  items.
- Accepted transcript text belongs in Transcript History and Paste Last Result
  recovery flows, not in the menu bar dropdown.
- Quit, application-menu Quit, Dock Quit, and `Command+Q` should ask the user
  to confirm before HoldType terminates.
- When quit is requested from the menu bar popover, the popover should dismiss
  before termination is requested, and the confirmation dialog should appear as
  the frontmost key prompt instead of opening behind other app windows.
- If launch at login is not enabled or still needs approval, quit confirmation
  should remind the user that `Right Command` dictation will be unavailable
  until HoldType is opened again.
- Updater-initiated relaunches should not show the quit confirmation. Detailed
  update behavior is defined in `features/software-updates.md`.
- Canceling the quit confirmation should keep HoldType running, including its
  menu bar item, shortcuts, and future dictation availability.
- Confirming the quit dialog should terminate the app cleanly.
- The app should show status changes during recording and transcription.
- After successful transcription and output handling, the compact menu status
  should return to `Ready` instead of showing a completion command such as
  `Done`. The menu should not show success details such as transcript-ready or
  inserted-transcript rows.
- Settings should be available from the menu bar.
- A floating indicator may be shown during recording and transcription when the
  setting is enabled.
- The floating indicator must not steal focus or interfere with the active app.
- Detailed floating indicator behavior is defined in
  `features/floating-indicator.md`.

## Invariants

- The app must not require Electron, React, Node.js, WebView UI, Tauri, or Rust
  for the first MVP.
- Menu state must reflect recording and transcribing state accurately.
- Errors must not be silent; they should be visible in menu status, settings, or
  an optional notification.
- No accounts, subscriptions, server-side app state, analytics, or telemetry are
  part of the MVP.

## Edge cases and failure policy

- If recording is already active, another Transcribe action must not
  create a parallel recording.
- If transcription is active, recording actions should be disabled or ignored in
  a way the user can understand.
- If settings cannot open, the app should show a clear recoverable error.
- If the floating indicator cannot be shown, core menu bar controls should
  still work.
- Closing Settings or Transcript History windows should not show the quit
  confirmation and should not terminate the app.
- Restarting macOS does not make global shortcuts available by itself. HoldType
  must be running, either because the user opened it or because launch at login
  is enabled and approved in macOS Login Items.

## Route / state / data implications

Core visible states are:

- idle
- recording
- transcribing
- completed and ready for another dictation
- error

Settings window state is separate from recording state. Opening or closing
settings must not start, stop, or cancel recording by itself.

Transcript History window state is separate from recording state. Opening,
closing, or clearing history must not start, stop, or cancel recording by
itself.

Dismissed transcription recovery prompts are separate from Transcript History.
Dismissing a prompt hides only the menu explanation; it must not delete a
recoverable failed attempt or its session-only retry audio.

## Verification mapping

- Add UI or manual app-run checks for menu presence, Transcribe/Stop label changes,
  translation and Paste Last Result disabled states, Settings opening,
  Transcript History opening, Quit, compact state display, and absence of
  transcript or successful output text in the menu when implementation exists.

## Unknowns requiring confirmation

- Whether future product naming changes should replace `HoldType` before
  packaging.
- Whether post-MVP menu bar polish needs a custom AppKit `NSStatusItem` for
  status-specific icons or lower-level tooltip control.
