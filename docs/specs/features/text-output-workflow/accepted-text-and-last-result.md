# Accepted Text and Last Result

- Node type: leaf
- Contract ID: `holdtype.macos.text-output.accepted`
- Domain ID: `holdtype.macos.text-output`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.text-output.accepted@1`
- Read when: final accepted value, Last Transcript, Last Result, menu privacy, or History relationship is in scope.
- Do not read when: only native insertion mechanics or stage-specific provider behavior is in scope.
- Maximum size: 100 physical lines.

## Final value

- Trim leading/trailing whitespace and newlines.
- Correction-enabled uses final corrected text; disabled/skipped uses accepted transcription.
- Successful translation uses final translated text.
- Last Transcript stores only final accepted output, not raw/corrected variants,
  and remains current-session state independent of durable History.
- Empty/whitespace final text is an error and is neither saved nor pasted.

## Menu and recovery surfaces

- Menu may show compact output status but never dictated transcript text.
- There is no manual Save Last Transcript command.
- Users recover via History or Paste Last Result when enabled.
- History enablement changes neither Last Result save nor paste behavior.

## Last Result

- With Keep last result enabled, save every accepted text after transcription
  and before automatic insertion completes, preserving recovery on handoff failure.
- Last Result is one app-owned in-memory current-session value, never
  `NSPasteboard.general`.
- `Control+Command+V` and menu Paste Last Result insert it when enabled.
- Turning Keep last result off disables new saves and Paste Last Result but not
  automatic insertion. Turning insertion off preserves Last Result recovery.
- No Last Result safely no-ops and reports unavailability when a visible surface exists.

## Dependencies

- [Text output](../text-output-workflow.md) — shared accepted-text invariants.
