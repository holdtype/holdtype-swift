# Transcription Failure Recovery Presentation

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.failure-ui`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.failure-ui@1`
- Read when: post-capture provider failure prompt, menu recovery, or platform retry output is in scope.
- Do not read when: only provider transport, History row internals, or pre-capture setup is in scope.
- Maximum size: 100 physical lines.

## Terminal presentation order

- Post-capture failure first reaches terminal status, then hides recording and
  transcribing indicators, then presents a blocking frontmost prompt.
- The first Retry click starts retry and is never consumed by stale UI cleanup.
- Prompt explains recording was not accepted as text and never auto-opens
  Settings or History.
- It offers only applicable Retry Transcription, Open OpenAI Settings, Open
  Transcription Settings, or Dismiss; no History shortcut.
- Menu retains compact error and matching actions as secondary surface.

## Credential and retry actions

- Invalid/revoked key after a request with resolved non-empty credential offers
  Open OpenAI Settings and retains retryable audio.
- Missing/inaccessible credential before upload is setup failure, not invalid-key provider rejection.
- Network, timeout, rate-limit, unavailable-provider, unreadable-response, and
  empty-result failures may offer Retry when outcome is definitively retryable.
- Retry validates playable audio before processing/request preparation, uses
  only retained audio plus current safe settings, and reuses no credential,
  payload, prompt, context, or dictionary from the failed attempt.
- A retry pressed during a short state transition queues until it can start and
  is not silently dropped.

## Platform output

- macOS prompt/menu Retry resumes dictation output: successful retry inserts
  when automatic insertion is enabled and falls back to Last Result on insertion failure.
- History Retry does not auto-insert by default because target/cursor may have
  changed; it may save Last Result and explain manual insertion.
- P4 iOS Retry ends at app-owned accepted-result presentation and never inserts
  into whichever external app is active.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared error classification.
