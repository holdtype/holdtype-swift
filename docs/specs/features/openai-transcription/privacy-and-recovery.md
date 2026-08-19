# Provider Privacy and Recovery Ownership

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.privacy`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.privacy@1`
- Read when: credentials, default logs, protected recovery audio, cache, or downstream checkpoint is in scope.
- Do not read when: only request field formatting or timeout mechanics is in scope.
- Maximum size: 100 physical lines.

## Credential boundary

- API key loads from secure storage into process-local cache and appears only in
  request authorization header, never scratch.
- Credential is resolved before capture via runtime cache, explicit Settings
  save, or one lazy noninteractive recording-start preflight.
- If reading would show system authentication UI, block recording and ask user
  in Settings to paste key again. Transcription never triggers Keychain UI.
- Service receives resolved session credential and never reads/changes Keychain,
  checks availability, or falls back to developer key.
- Post-capture failure may explain and navigate only; it never validates,
  rewrites, saves, clears, or deletes Keychain state.

## Logs and failure ordering

- Default logs contain compact started/succeeded/timed-out/failed category only,
  never key/header, audio, prompt/context/dictionary, transcript, response, or path.
- Terminal failure precedes indicator hiding, which precedes blocking prompt.
- Failed transcription never overwrites prior successful text.

## Audio ownership after provider work

- Success may delete ordinary completed audio when cache retention is off;
  configured-limit success keeps separate bounded recovery copy/text to explicit
  Delete or pruning.
- Provider/timeout/validation failure or stopped-clock mismatch keeps protected
  recovery until explicit Delete/Discard, even when cache and accepted History are off.
- Cache-on may retain file for Finder and accepted-row local Play while enabled/existing.
- Successful configured-limit row has Play/Delete, never Retry or duplicate accepted row.
- Failed configured-limit identity survives relaunch; Retry success promotes same row.
- Once response accepted, provider Retry stays permanently disabled even if
  saved metadata fails. Dispatch seal and repair metadata prevent second upload;
  total metadata loss restores non-retryable outcome-uncertain playable audio.
- Raw accepted text is checkpointed before downstream work. Post-processing
  failure yields truthful raw label, text, Play, Delete, Save Raw Transcription
  only—no seal clear, translation-success claim, or provider Retry.
- Normal cache defaults to 10 most recent; unlimited requires explicit Settings choice.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared privacy and recovery invariants.
