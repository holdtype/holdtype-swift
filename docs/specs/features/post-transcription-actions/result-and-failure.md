# Translation Result and Failure

- Node type: leaf
- Contract ID: `holdtype.macos.post-transcription-actions.result`
- Domain ID: `holdtype.macos.post-transcription-actions`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.post-transcription-actions.result@1`
- Read when: translation ordering, cleanup, strict failure, cancellation, or output is in scope.
- Do not read when: only Settings or request-value construction is in scope.
- Maximum size: 100 physical lines.

## Ordering and acceptance

- Translation follows accepted transcription, optional fail-open correction,
  and local cleanup.
- Successful translation optionally runs one final plain-typography pass only;
  no correction, emoji, or replacement rerun. Empty cleanup result falls back
  to pre-cleanup translation.
- Final translated text becomes Last Transcript, History, Last Result, and insertion.
- Successful provider token counts may create local text-usage event without text/state changes.

## Strict failure and cancellation

- Missing/invalid key, rate limit, network/provider/timeout, unreadable or empty
  response visibly fails session; no output or normal accepted History occurs.
- Cancellation is strict, not fail-open; it cancels in-flight transport, reports
  cancelled, rejects late response, and never accepts source text as translation.
- Timeout stays distinct, cancels transport, and completes boundedly without
  waiting for loader. Repeated/no-active cancel is safe; older completion cannot
  affect newer request.
- Protected recovery may keep raw transcription only in row labelled
  `Raw transcription recovered — post-processing failed`, with Play, Delete,
  Save Raw Transcription, no translated claim, and no provider Retry.
- Correction failure remains fail-open and translation receives accepted transcription.
- Insertion failure after translation keeps translated text accepted/recoverable.
- Unmatched shortcut key-up creates no action.
- Configuration recovery targets Translation, not API Key or Transcription.

## Verification

Cover defaults/persistence, intent key lifecycle, language/custom validation,
prompt reset and legacy Russian-to-English setting migration,
success/disabled/invalid/failure, typography-only final
pass, cancellation/timeout/late response/next request, narrow runtime value,
boundary exclusions, and no live API.

## Dependencies

- [Post-transcription actions](../post-transcription-actions.md) — shared strict failure.
