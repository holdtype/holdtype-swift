# Fixes and Paste Last Result Hotkeys

- Node type: leaf
- Contract ID: `holdtype.macos.global-hotkey.text-actions`
- Domain ID: `holdtype.macos.global-hotkey`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.global-hotkey.text-actions@1`
- Read when: Paste Last Result or immediate Fixes shortcut behavior is in scope.
- Do not read when: only dictation capture or assignment persistence is in scope.
- Maximum size: 100 physical lines.

## Paste Last Result

- Default assignment is `Control+Command+V`; it is not a dictation shortcut.
- On release, it inserts current Last Result into the active app only when Keep
  last result is enabled. Disabling retention disables the action.
- With no Last Result it safely no-ops and reports unavailability when a visible
  surface exists.
- Release timing prevents held modifiers from affecting synthetic insertion;
  generated text events clear modifier flags.
- Paste Last Result never writes transcript text to the macOS system clipboard.
- Missing Accessibility after transcription follows the recovery behavior in
  [text output](../text-output-workflow.md) without using the system clipboard.

## Immediate Fixes

- Default assignment is `Option+J`.
- Invocation requires the configured key and every configured modifier to have
  been observed together. Bare `J` is not invocation and triggers neither
  Accessibility inspection nor Fixes UI.
- A confirmed shortcut captures the current external target and opens the
  palette only when compatible under [Text Fixes](../text-fixes.md). It neither
  records nor reuses another product's current-line behavior.
- The listener preserves ordinary input. Bare keys and failed or unavailable
  registration never make typing disappear.
- `Option+J` conflict leaves dictation and menu controls usable, reports only
  Fixes unavailable, and creates no menu fallback for the palette.

## Invariants

- Fixes target capture precedes HoldType focus.
- Release-triggered text actions do not start or attach to recording sessions.
- No source, prompt, result, or Last Result text is logged by shortcut handling.

## Dependencies

- [Global hotkey](../global-hotkey.md) — shared registration invariants.
- [Text output](../text-output-workflow.md) — insertion and Accessibility recovery.
- [Text Fixes](../text-fixes.md) — target compatibility and palette ownership.
