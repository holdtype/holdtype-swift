# macOS Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting shipped macOS-only HoldType behavior.
- Do not read when: the task is iOS-only or belongs to an unmigrated shared capability.
- Maximum size: 100 physical lines.

macOS is the shipped product boundary. Migration preserves its existing public
behavior conservatively as legacy-released until an explicit release baseline
records finer-grained revisions.

## Children

- [Menu bar app shell](../menu-bar-app-shell.md) — menu bar lifecycle, primary
  commands, compact state and status, recovery, and quit behavior.
- [Microphone input](../microphone-text-input.md) — device selection, capture,
  finalization, recovery, cache, and transcript handoff.
- [Global hotkey](../global-hotkey.md) — Dictation, Translation, Fixes, and
  Paste Last Result assignments and macOS-wide activation.
- [Floating indicator](../floating-indicator.md) — optional non-activating
  recording, countdown, and transcription feedback.
- [Transcript History](../transcript-history.md) — accepted transcript
  persistence, recording recovery, retry, playback, copy, and deletion.
- [Text output](../text-output-workflow.md) — Last Transcript, Last Result, and
  Accessibility-gated active-app insertion.
- [Post-transcription actions](../post-transcription-actions.md) — strict
  translation-mode intent, request, and accepted output.
- [Text Fixes](../text-fixes.md) — immediate external-text transformations,
  `Option+J`, Voice Prompt, target safety, and Manage Fixes.
- [Built-in writing skill](../text-fixes-writing-skill.md) — optional app-owned
  Humanize text route for custom macOS Fixes.
- [Privacy and permissions](../privacy-and-permissions.md) — TCC state,
  setup/credential gating, disclosure, retention, and diagnostics boundaries.
- [Settings and secret storage](../settings-and-secret-storage.md) — macOS
  window routing, local defaults, Keychain credential, and feature controls.

## Pending macOS domains

Other macOS and shared contracts remain selectable through the
[legacy authority index](../../index.md) until their own batches are migrated.

## Dependencies

- [Specification root](../../README.md) — project-wide status and precedence
  conventions.
