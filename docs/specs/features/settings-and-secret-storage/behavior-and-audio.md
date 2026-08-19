# Behavior And Audio Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.BEHAVIOR`, `SETTINGS.AUDIO`
- Read when: insertion, Last Result, cues, indicator, microphone, recording bounds, login, or Dock is in scope.
- Do not read when: only transcription provider configuration is in scope.
- Maximum size: 100 physical lines.

- Automatic insertion controls accepted-text insertion. Keep Last Result owns
  app recovery for `Control+Command+V`/Paste Last Result, never system clipboard,
  and does not disable insertion. Sounds are short/non-verbal; indicator is optional.
- Audio Input starts Behavior. Picker lists System Default then current devices.
  Default follows macOS. Explicit device persists stable ID/name through
  disconnect; never silently substitutes. Disconnection blocks before capture
  with choose/default actions; reconnect resolves automatically and lists refresh.
- Recording tail choices are Off, 0.5, 1.0, 1.5, 2.0 seconds; default Off. It is
  fixed post-release delay, never endpoint/silence analysis.
- Maximum length offers whole minutes 1–15, default 5, explains local/provider
  bounding and auto-finalize/save. Freeze at start; changes affect next attempt.
- Start at login defaults off, requires explicit registration, reflects Login
  Item/approval-needed state, links review, and is mirrored in Permissions as
  availability—not required TCC.
- `DOCK-SETTINGS-1..3`: Show in Dock defaults off, applies immediately and
  persists, changing only activation presence—not login, menu, shortcuts,
  recording, or ordinary SwiftUI windows.
