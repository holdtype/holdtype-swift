# Menu Bar State, Status, and Recovery

- Node type: leaf
- Contract ID: `holdtype.macos.menu-bar-shell.status`
- Domain ID: `holdtype.macos.menu-bar-shell`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.menu-bar-shell.status@1`
- Read when: compact app state, status text, transcription recovery, or indicator routing is in scope.
- Do not read when: only command ordering or process/Dock lifecycle is in scope.
- Maximum size: 100 physical lines.

## Core states

The visible app-shell states are idle, recording, transcribing, completed and
ready for another dictation, and error. State changes during recording and
transcription must be truthful.

- After successful transcription and output handling, compact status returns
  to `Ready`; it does not show a completion command such as `Done` or success
  details such as transcript-ready or inserted-transcript rows.
- Dynamic menu text stays compact. Menu items contain no long diagnostics,
  dictated transcript text, or successful output-status messages.
- Accepted transcript text belongs in Transcript History and Paste Last Result
  recovery, not in the menu bar dropdown.

## Transcription recovery

- A completed recording that fails during transcription presents a frontmost
  prompt explaining the failure and only applicable actions: Try Again, Open
  OpenAI Settings, Open Transcription Settings, or Dismiss.
- The prompt retains the compact native dialog hierarchy used before the
  2026-08-05 Settings, Fixes, and History work: one prominent accent-colored
  affirmative default and a subdued Dismiss action, with no equal-weight
  generic buttons or exposed window chrome.
- This prompt rule is app-shell-only; Settings, Fixes, and Transcript History
  retain their own feature-specific surfaces.
- Opening the menu afterward shows one compact line such as
  `Error: Timed out` and the same applicable compact recovery actions.
- Recovery does not auto-open Settings or Transcript History; navigation occurs
  only after the user chooses an action.
- The recovery block has no Transcript History shortcut; History remains a
  normal menu item.
- Dismissing the prompt hides only its menu explanation and does not delete a
  recoverable failed attempt or its session-only retry audio.

## Independent state

- Settings state is separate from recording state; opening or closing Settings
  does not start, stop, or cancel recording.
- Transcript History state is separate from recording state; opening, closing,
  or clearing it does not start, stop, or cancel recording.
- Dev Vlogs window state is separate from recording state and cannot affect
  ordinary dictation merely by opening, closing, or navigating.

## Floating indicator routing

- The indicator may appear during recording and transcription when enabled.
- It does not steal focus or interfere with the active app.
- Failure to show it does not disable core menu controls.
- Detailed behavior is owned by the
  [Floating indicator contract](../floating-indicator.md).

## Dependencies

- [Menu bar app shell](../menu-bar-app-shell.md) — shared scope and invariants.
- [Transcript History](../transcript-history.md) — accepted and failed-attempt ownership.
- [Text output](../text-output-workflow.md) — successful output and Last Result.
- [Floating indicator](../floating-indicator.md) — indicator presentation and lifecycle.
