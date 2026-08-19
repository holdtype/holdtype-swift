# Text Output Workflow

- Node type: hybrid
- Contract ID: `holdtype.macos.text-output`
- Domain ID: `holdtype.macos.text-output`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.text-output@1`
- Read when: Last Transcript, Last Result, active-app insertion, or recovery paste is in scope.
- Do not read when: only transcription, correction internals, or History persistence is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Final accepted text becomes useful through current-session Last Transcript,
optional app-owned Last Result, and bounded Accessibility-gated bulk insertion
into the current active macOS app.

## Children

- [Accepted text and Last Result](text-output-workflow/accepted-text-and-last-result.md) — final-stage selection, recovery slot, menu privacy, and History independence.
- [Insertion and failure](text-output-workflow/insertion-and-failure.md) — automatic/recovery paste, Accessibility, target timing, and bounded failure.

## Shared invariants

- Failed transcription, correction, action, or delivery never discards a prior
  success or silently accepts the wrong stage's text.
- The macOS system clipboard is never transcript storage, fallback, or
  restorable state for this workflow.
- Default logs contain no transcript text.
- Automatic insertion and Last Result save/paste each have independent settings.

## Dependencies

- [Text correction](text-correction.md) — optional fail-open stage.
- [Post-transcription actions](post-transcription-actions.md) — strict translation intent.

Optional durable accepted recovery remains owned by `transcript-history.md`;
it consumes final output without creating a reverse dependency cycle.

## Unknowns

- Future punctuation/editing commands and recording-start versus paste-time
  target pinning require separate decisions.
