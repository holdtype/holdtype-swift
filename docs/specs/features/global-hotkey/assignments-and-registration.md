# Shortcut Assignments and Registration

- Node type: leaf
- Contract ID: `holdtype.macos.global-hotkey.registration`
- Domain ID: `holdtype.macos.global-hotkey`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.global-hotkey.registration@1`
- Read when: shortcut Settings, assignment validation, persistence, collision, or Input Monitoring is in scope.
- Do not read when: only action-specific key semantics are in scope.
- Maximum size: 100 physical lines.

## Settings editor

- Shortcut Settings is an editor, not help-only. It lists Dictation,
  Translation, Fixes, and Paste Last Result with current assignment and mode.
- Dictation and Translation are hold-to-record; Fixes and Paste Last Result run
  on release.
- Assignments are captured locally and applied only after the candidate is valid
  and registration succeeds.
- A candidate cannot duplicate another HoldType action or use an unsupported
  key. Failure preserves the prior working assignment and shows a concise error.
- The section has no Translation enable toggle, language, model, or prompt;
  those remain in Translation Settings.
- The menu exposes the active shortcut near Transcribe when practical.

## Persistence and state

- Assignments are versioned local runtime configuration. First load migrates
  spec-defined defaults; only validated assignments persist.
- Registration state is `registered` or `unavailable`; a hotkey press token may
  own the active recording session, and that session carries its output intent.
- Fixes has an independent registration status.
- Translation enablement is not shortcut configuration.

## Registration failure

- Launch-time failure or ownership by macOS/another app leaves menu controls
  usable and shows clear hotkey-unavailable status.
- If none registers, menu Transcribe and Stop Recording remain supported.
- Right Command failure identifies Dictation as unavailable.
- `Option+J` failure identifies only Fixes and does not change Dictation.
- Accessibility permission is not required to start recording.
- Missing Input Monitoring may make native listening unavailable. Settings
  exposes its state and a bounded next action, but absence does not imply hidden
  recording, auto-open recovery, or disable menu capture.

## Dependencies

- [Global hotkey](../global-hotkey.md) — shared shortcut invariants.
- [Settings and secrets](../settings-and-secret-storage.md) — editor and permission presentation.
- [Menu bar shell](../menu-bar-app-shell.md) — manual fallback and hints.
