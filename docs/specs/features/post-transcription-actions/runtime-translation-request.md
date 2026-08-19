# Runtime Translation Request

- Node type: leaf
- Contract ID: `holdtype.macos.post-transcription-actions.request`
- Domain ID: `holdtype.macos.post-transcription-actions`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.post-transcription-actions.request@1`
- Read when: `TextTranslationRequest` input, captured settings, or provider boundary is in scope.
- Do not read when: only UI preflight, final typography, or failure presentation is in scope.
- Maximum size: 100 physical lines.

## Narrow value

- Contains exactly one validated `AcceptedTranscript`, one
  `TranslationConfiguration`, and optional source code resolved from the same
  captured settings snapshot.
- Same+Auto stores no code; Same+fixed/custom stores effective transcription
  code; Override stores its validated code.
- It does not retain full transcription configuration, model, or freeform prompt.
- Construct only for effective Translation intent after non-empty transcription
  and fail-open correction/local pipeline.
- One captured snapshot governs transcription, correction, translation, final
  acceptance, and output. Invalid source/target creates no request/network call.
- macOS failed-attempt Retry stays transcription-only and invents no Translation intent.

## Provider boundary

- Adapter receives accepted source, resolved route, target/model/prompt, and
  separate transient `OpenAICredential` only.
- It receives no full Settings, transcription prompt/context/dictionary/emoji,
  replacements, History/retention, output preference, audio, keyboard/App Group state.
- Value is runtime-only, `Equatable`, `Sendable`, non-Codable, with no identity,
  intent, timestamp, recovery, response, result, copy, persistence, log, App Group,
  keyboard, or durable-journal semantics.
- Provider transport, timeout, and real cancellation stay adapter-owned.
- Final plain-typography cleanup is controller-owned and may run once after
  success without correction, emoji, or replacement reruns.

## Dependencies

- [Post-transcription actions](../post-transcription-actions.md) — shared request scope.
