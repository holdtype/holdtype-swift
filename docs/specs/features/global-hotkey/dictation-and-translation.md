# Dictation and Translation Hotkeys

- Node type: leaf
- Contract ID: `holdtype.macos.global-hotkey.dictation`
- Domain ID: `holdtype.macos.global-hotkey`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.global-hotkey.dictation@1`
- Read when: hold-to-record, Right Command, key race, or translation-intent behavior is in scope.
- Do not read when: only assignment editing, Fixes, or Paste Last Result is in scope.
- Maximum size: 100 physical lines.

## Default and native capability

- Default dictation is single-key `Right Command` hold-to-record.
- There is no automatic alternate or toggle fallback. `Command+Space`,
  `Option+Space`, and `Control+Space` are not default dictation shortcuts.
- Native registration reports active only after reliable key-down and key-up
  observation and must distinguish Right Command from generic Command.
- If reliable key-up is unavailable, registration is unavailable and manual
  menu controls remain usable; interaction never silently becomes toggle mode.

## Hold-to-record

- Key down starts exactly one recording while idle and permitted; key up stops
  that same session and starts transcription.
- If key up arrives after capture began while start is still completing, the
  release is remembered and stops that session as soon as start succeeds.
- If key up arrives while start awaits permission or setup, later permission
  cannot begin a recording. HoldType returns Ready without audio, History,
  transcription, Retry, or Dismiss.
- Repeat or second key down while already held is ignored.
- Key up without a matching hotkey-owned recording is ignored.
- A remembered key up is discarded if in-flight start fails or is blocked;
  only the start failure is shown.
- A key down during menu-started recording is ignored and never attaches that
  session to a new key token.
- During transcription the hotkey starts no recording; menu and indicator show
  transcribing state.

## Translation intent

- When enabled, `Right Command+Option` is a separate hold-to-record intent that
  requests configured post-transcription translation and never replaces normal
  Right Command dictation.
- Option before, with, or after Right Command while the session is starting or
  recording all request translation for that same session.
- Once requested, releasing Option before Right Command does not downgrade the
  session to ordinary dictation.

## Failure policy

- If microphone permission is denied, the shortcut shows the same blocked state
  as menu start and never enters recording.
- If the shortcut service stops or loses its event stream during recording,
  HoldType visibly fails or stops rather than continuing hidden capture.

## Dependencies

- [Global hotkey](../global-hotkey.md) — shared shortcut invariants.
- [Microphone input](../microphone-text-input.md) — recording state and authority.
- [Post-transcription actions](../post-transcription-actions.md) — translation processing.
