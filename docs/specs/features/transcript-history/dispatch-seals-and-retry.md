# Dispatch Seals and Provider Retry

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.dispatch`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.dispatch@1`
- Read when: provider dispatch seal, Retry, uncertain outcome, or raw-text recovery is in scope.
- Do not read when: only local playback, accepted retention, or row deletion is in scope.
- Maximum size: 100 physical lines.

## Fail-closed dispatch seal

- Accepted or unresolved dispatch keeps its compact seal for the protected
  audio's entire lifetime, including after result save.
- Cleanup, clear, startup pruning, and retention remove the seal only after the
  exact owned audio is confirmed gone. If rollback and audio removal both fail,
  relaunch keeps the playable orphan non-retryable.
- Definitive pre-dispatch/provider-rejection failure may retire its seal only
  after a retryable row is durably written. Each explicit Retry writes a fresh
  seal before upload.

## Uncertain outcomes and retry

- Timeout, transport loss, or cancellation after dispatch begins is not
  definitively retryable. The lifetime seal remains, the row becomes
  `Transcription outcome uncertain`, and ordinary Retry is hidden.
- `Transcribe Again…` requires confirmation that another submission may
  duplicate transcription, then uses retained audio and current safe Settings.
- If retryable transition persistence fails, the previous seal remains and
  relaunch restores the same uncertain, confirmation-gated state.
- A failed row Retry uses current transcription settings and API key.
- Retry success replaces a normal failed row with accepted transcript history,
  updates Last Transcript, and optionally Last Result. Retry failure keeps the
  row, reason, and incremented count while preserving prior Last Transcript.

## Downstream raw-text recovery

- Accepted provider text is checkpointed before correction or translation.
- Downstream failure yields `Raw transcription recovered — post-processing
  failed`, contains raw accepted text, and offers `Save Raw Transcription`.
- Saving retains that truthful label; it never claims translation success or
  returns to provider Retry.

## Terminal provider attempt

- Every started attempt ends saved, failed, outcome-uncertain, or another
  explicit terminal classification.
- Preparation/validation failure after `Transcribing…` still ends that state.
  A retained seal may block replay but not terminal-state persistence.
- Dismiss hides only the message after truthful terminal state; it changes no
  eligibility, error, row, or attempt completion.

## Dependencies

- [Transcript History](../transcript-history.md) — shared recovery invariants.
- [OpenAI transcription](../openai-transcription.md) — provider outcome classification.
