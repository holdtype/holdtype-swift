# Transcription Timeout, Retry, and Errors

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.timeout`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.timeout@1`
- Read when: total deadline, cancellation, retry authority, or provider/local error mapping is in scope.
- Do not read when: only prompt composition, scratch maintenance, or downstream output is in scope.
- Maximum size: 100 physical lines.

## Deadline and cancellation

- Default 60-second maximum covers multipart preparation, upload, response, and
  approved replay; it does not limit capture, idle keyboard availability, or delivery lifetime.
- Cancellation synchronously cancels actual transport. Repetition/no active
  request is safe no-op and returns existing `cancelled` error.
- Parent cancellation reaches same task; late response is discarded before
  validation/parsing even with uncooperative loader.
- Caller finishes boundedly after transport cancel without waiting for loader or
  local I/O; abandoned completion performs only bounded identity-safe cleanup.
- Cleanup is request-identity-aware so older completion cannot clear/cancel newer work.

## Dispatch boundary and retry

- Timeout before dispatch is visible `Transcription timed out` and retryable.
- Timeout, transport loss, or cancellation after dispatch is uncertain: cancel
  transport, retain seal/playable audio, hide Retry, offer confirmation-gated
  `Transcribe Again…` across prompt/menu/History.
- No silent retry. Explicit retry is a new bounded request using retained source,
  current safe settings, fresh boundary/body; old scratch is never reused.
- Future one bounded transient retry requires a user-visible delay policy and
  never applies to invalid credential/settings/audio, empty text, or rate limit.

## Error mapping

- Missing key: key required before transcription. Keychain read/inaccessible:
  saved key unavailable, no unauthenticated request, no invalid-key claim or storage change.
- Provider invalid/revoked key: keep recovery and offer Open OpenAI Settings without auto-open.
- Network before dispatch is retryable; loss after dispatch is uncertain.
- Rate limit asks try later; unavailable/server error asks retry later.
- Bad model/language/prompt/file points to settings/format.
- Unsupported, changed-during-preparation, or ≥25,000,000-byte audio cannot be sent.
- Scratch create/protection/write failure preserves source and is local
  preparation failure, never provider rejection.
- Empty transcript reports no speech/text and preserves prior transcript.
- User cancel avoids new upload before start; in-flight request is cancelled
  when practical and result discarded.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared cancellation and recovery.
