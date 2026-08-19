# iOS Voice Relaunch Recovery

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-state.relaunch@1`
- Read when: process launch, orphan audio, or interrupted provider stages matter.
- Do not read when: only live capture flow matters.
- Maximum size: 100 physical lines.

- Relaunch reconciles locally with zero provider calls. Before ordinary launch
  observation, one bounded repair inspects only canonical recording/finalizing
  metadata and exact descriptor-open source.
- Non-empty regular audio below byte bound becomes completed. Duration below
  300 ms, above finalized bound, invalid metadata, or validator timeout stores
  internal unknown `0`; validator max is two seconds. Empty/descriptor-absent is
  Discard-only, never auto-deleted. Oversize/protection/source/write uncertainty
  stays blocked/retriable. Launch repair deletes no source bytes.
- Unknown audio stays visible with Play and explicit Transcribe/Discard, never
  auto-provider. Explicit validated admission occurs once; success uses newest-
  five Saved Recording retention regardless of cache because boundary is unknown.
  Foreground opportunities observe state and do not run orphan repair.
- Relaunched transcription without accepted checkpoint, or live dispatch ending
  timeout/transport loss/cancel with unknown response, is failed with replay
  blocked and Play/Discard. Never downgrade it on relaunch.
- Relaunched downstream processing keeps checkpoint: correction-in-flight fails
  open locally; translation-ready needs explicit Retry; translation-in-flight
  stays Play/Discard; output-ready accepts locally.
- `acceptedCleanup` may idempotently append matching Latest to enabled History
  then clean. Protected limit audio first retries local publication only.
  Never repeat provider, duplicate History, or retain Pending solely for History.
- Corrupt/unsupported/oversized/locked/uncertain state is visible, blocks second
  recording, and preserves bytes absent proven safe absence.
- Duration is valid through frozen limit +2 s, absolute ceiling 902 s. Positive
  media beyond tolerance uses clamped live elapsed or unknown `0`, never deletion;
  oversize/identity/protection uncertainty remains blocked.
