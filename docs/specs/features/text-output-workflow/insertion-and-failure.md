# Active-App Insertion and Failure

- Node type: leaf
- Contract ID: `holdtype.macos.text-output.insertion`
- Domain ID: `holdtype.macos.text-output`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.text-output.insertion@1`
- Read when: automatic insertion, recovery paste, Accessibility, host target, or delivery failure is in scope.
- Do not read when: only accepted-value selection or Last Result persistence is in scope.
- Maximum size: 100 physical lines.

## Delivery

- Automatic insertion defaults on through local UserDefaults and inserts each
  accepted transcript at the current active-app cursor.
- Automatic and recovery paste deliver one bulk handoff, never visible
  per-character typing or truncation from character delays.
- Both use the same native Accessibility-gated boundary—no Electron, Node,
  AppleScript helper, or system-clipboard fallback.
- Target is current active app at insertion time unless a future contract pins it at start.

## Permission and failure

- Missing Accessibility performs no simulated insertion and no clipboard fallback.
- Failure/timeout preserves Last Result when enabled and shows recoverable output
  status when visible UI exists.
- Failed delivery preserves current-session Last Transcript and any enabled recovery.
- Host unavailable behaves as recoverable output failure.
- Event posting and paste delays are bounded.
- Optional correction failure proceeds with accepted transcription; required
  translation failure performs no output and preserves previous success.

## Verification

Cover insertion success, automatic Last Result save, both disabled settings,
shortcut/menu paste, missing Accessibility, empty output, handoff failure, and
absence of menu transcript text.

## Dependencies

- [Text output](../text-output-workflow.md) — shared delivery invariants.
