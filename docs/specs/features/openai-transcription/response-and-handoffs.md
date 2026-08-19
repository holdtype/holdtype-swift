# Transcription Response and Downstream Handoffs

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.response`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.response@1`
- Read when: JSON text acceptance, correction/action/output, or usage-estimate handoff is in scope.
- Do not read when: only request construction, retry UI, or transport mechanics is in scope.
- Maximum size: 100 physical lines.

## Accepted response

- Request normal JSON and read `text`; trim and reject empty/whitespace as failed session.
- Accepted non-empty text becomes Last Transcript before optional downstream work.
- Correction receives accepted text only, never provider response. Transcription
  stays successful if correction is skipped or fails open.
- Post-transcription actions run only after accepted transcription and receive
  corrected text when enabled, otherwise accepted text.
- Output receives final post-action text.
- Failed transcription never overwrites a previous successful transcript.

## Usage estimate

- Success may record local estimate from selected model and completed duration;
  it is not provider usage receipt.
- `gpt-transcribe` snapshots reviewed `$0.0045` per audio minute.
- Pricing rollout backfills only canonical `gpt-transcribe` records whose whole
  price snapshot is absent; it is idempotent and changes neither other models
  nor any known snapshot.
- Usage records store no credential, audio, prompt/context/dictionary,
  transcript, payload, or full response.

## Recovery handoff

- Recoverable post-capture provider failure creates a failed attempt when
  recovery History is enabled; it is not accepted text.
- Recovery stores compact state plus protected local audio; successful
  maximum-duration row additionally stores only accepted text.
- Normal cache receives only completed URL and retention setting. History may
  receive a session-only cache reference for local Play, never upload, retry,
  log, or persist that path.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared response acceptance.
