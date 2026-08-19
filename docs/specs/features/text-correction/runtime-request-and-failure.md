# Runtime Correction Request and Failure

- Node type: leaf
- Contract ID: `holdtype.shared.text-correction.request`
- Domain ID: `holdtype.shared.text-correction`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.text-correction.request@1`
- Read when: runtime correction request, provider timeout/cancellation, or fail-open output safety is in scope.
- Do not read when: only settings UI, Library editing, or persistence is in scope.
- Maximum size: 100 physical lines.

## Narrow runtime request

- `TextCorrectionRequest` contains exactly validated `AcceptedTranscript`, one
  `TextCorrectionConfiguration`, and one `TranscriptPostProcessingConfiguration`.
- Normal path projects attempt snapshot; explicit failed-attempt Retry projects
  current settings once and freezes them.
- Adapter receives only accepted text/configuration plus separate transient
  `OpenAICredential`; emoji/rules remain local and never enter provider request.
- Remote-off still runs local cleanup, emoji, and ordered rules without provider contact.
- Value is runtime-only, `Equatable`, `Sendable`, non-Codable, with no identity,
  intent, timestamp, recovery, response, result, copy, persistence, log, App Group,
  keyboard, or journal semantics.

## Timeout and cancellation

- Provider has explicit maximum wait. Cancellation stops actual transport,
  finishes cancelled, and rejects late response.
- Timeout remains distinct while cancelling transport. Completion is bounded
  without waiting for loader; repeated/no-active cancel is safe, and old request
  completion cannot affect newer work.

## Fail-open policy

- Missing/invalid key, rate limit, network/provider/timeout, unreadable response,
  explicit cancellation, empty, or unsafe-length output preserves accepted transcription.
- Explicit correction cancellation fails open unless containing session itself is cancelled.
- Local cleanup empty preserves pre-cleanup value.
- Replacement execution order and case-insensitive literal matching are preserved.

## Dependencies

- [Text correction](../text-correction.md) — shared fail-open boundary.
