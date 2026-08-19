# Runtime Request and iOS Bounded Reader

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.runtime-request`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.runtime-request@1`
- Read when: `AudioTranscriptionRequest` or iOS pending-recording reader handoff is in scope.
- Do not read when: only prompt source acquisition, multipart filesystem security, or response UI is in scope.
- Maximum size: 100 physical lines.

## URL request value

- macOS compatibility request contains exactly one app-local audio URL, one
  resolved non-empty model, optional validated language, and frozen composition.
- Initializer resolves one `TranscriptionConfiguration` without retaining it;
  freeform prompt is not duplicated outside composition.
- Blank model defaults; Auto/blank custom language omits field; valid fixed/custom
  normalizes; invalid non-empty custom produces typed pre-audio validation error.
- Normal capture uses attempt settings snapshot and gated context. Failed Retry
  resolves current safe settings once, creates fresh composition without Nearby
  Text, and reuses only retained audio URL.
- `OpenAICredential` stays a separate transient argument.
- Request is `Equatable`, `Sendable`, non-Codable and contains no duration,
  size, identity, timestamp, recovery/output policy, authorization, response,
  persistence, App Group, keyboard, log, or scratch lifecycle semantics.

## iOS reader request

- P4 iOS uses a separate reader request only inside one-shot
  `IOSPendingTranscriptionHandoff.execute`; URL request remains macOS boundary.
- It exposes validated format, duration, byte count, model, optional language,
  composition, and bounded offset reads—no URL/path/handle/descriptor/identity.
- Only `m4a`/`wav`, positive duration ≤902 seconds, and positive size strictly
  below 25,000,000 bytes are valid. Capture first validates selected limit plus
  two-second close tolerance; 902 is HoldType's 15-minute safety ceiling.
- Reads use nonnegative offset and positive size ≤64 KiB. Over-return, early
  EOF, or data past declared boundary fails locally before OpenAI.
- Preparation reads directly into protected scratch, verifies exact declared
  completion and empty EOF, and never materializes an equivalent source path.
- One 60-second deadline covers reader, preparation, upload/replay, and response;
  it starts after closed durable Pending and is independent of keyboard Ready
  expiry and Listening deadline.
- Cancellation invalidates reader and transport, rejects late completion, and
  never waits indefinitely for blocked read/cleanup.
- P4 Retry gets fresh authorization/transcription ID/settings/library/consent/
  credential/composition/boundary/body; it reuses no prior request material.
- OpenAI package owns only neutral reader contract and does not import Persistence.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared request bounds.
