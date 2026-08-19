# Saved Recordings, Voice Prompt, and Feedback

- Node type: leaf
- Contract ID: `holdtype.shared.recording-durability.recovery`
- Domain ID: `holdtype.shared.recording-durability`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.recording-durability.recovery@2`
- Read when: playable recovery, provider authority, Voice Prompt audio, or interruption feedback is in scope.
- Do not read when: only initial cause classification or iOS warm handoff is in scope.
- Maximum size: 100 physical lines.

## Saved Recording and provider authority

- Before provider work, every finalized non-empty, duration-eligible source is
  durably owned and locally validated. It becomes visible only when the
  supported-audio decoder proves playable audio; byte count, extension, and
  container metadata alone are insufficient.
- Malformed, truncated, header-only, renamed non-audio, or otherwise
  undecodable positive-byte artifacts remain owned but excluded from History,
  Play, Transcribe, Retry, and Transcribe Again. Exclusion never deletes them.
- Involuntary/internal termination is provider-free unless Finish or configured
  limit already owned provider authority.
- Provider-free rows offer Play, Transcribe, and exact-attempt Delete.
- Provider failure retains Play and Retry/Transcribe. Ambiguous outcome hides
  Retry and offers confirmation-gated `Transcribe Again…`, explicitly warning
  that the saved audio will be submitted again.
- Local finalization/persistence failure is visible immediately, not only after relaunch.
- Accepted-History publication and cleanup are a recoverable transaction; the
  final playable owner remains until accepted row or durable repair marker commits.
- Count retention never silently evicts unresolved recordings. Storage pressure
  may block provider work and request review; only explicit Delete removes them.

## Voice Prompt Fix recordings

- Voice Prompt follows the same ownership and exact-once causes but persists
  closed completion kind `voicePrompt`, not ordinary dictation intent.
- Successful transcription and Fix remove recovery without accepted History or
  ordinary output.
- Failure/interruption retains one playable owner with Play and Delete only—no
  ordinary Retry, Transcribe Again, insertion, or delayed Fix, because the
  external Accessibility target cannot be restored.
- While palette and target remain alive, in-memory retry may reuse audio under
  the existing dispatch seal; it is never reconstructed after dismissal/relaunch.

## User feedback and privacy

- Involuntary stop immediately reports `Recording interrupted — saved to History`
  or platform equivalent. Keyboard-originated recovery remains in its handoff sheet.
- UI claims saved audio only when a durable playable owner loads.
- Local validation failure says `This saved recording can’t be opened, so it
  can’t be played or transcribed.` and exposes no impossible action or provider detail.
- Default logs contain terminal cause, attempt ID, durability outcome, and
  provider authorization, never audio, transcript, secrets, or paths.

## Verification

- Assert exact-one ownership, at-most-once dispatch after ownership, no dispatch
  for involuntary termination, callback safety, and bounded no-upload relaunch repair.
- Voice Prompt rows never expose dictation Retry or recreate external targets.
- Fault injection covers History write failure and all recovery classifications.

## Dependencies

- [Recording durability](../recording-durability-and-interruption.md) — shared ownership rules.
