# Runtime Prompt Composition

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.prompt-composition`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.prompt-composition@1`
- Read when: `TranscriptionPromptComposition` inputs, projections, echo guards, or persistence boundary is in scope.
- Do not read when: only multipart transport, recovery UI, or Settings acquisition is in scope.
- Maximum size: 100 physical lines.

## Frozen input

`TranscriptionPromptComposition` is a pure transient value receiving exactly a
resolved optional freeform prompt, optional already-acquired/authorized
`TranscriptionPromptContext`, one `EmojiCommandsConfiguration`, and one
normalized `CustomDictionary`.

It receives no full Settings, model, language, credential, audio, response,
output preference, History, or permission state.

## Projections

- `gpt-transcribe` projection joins non-empty freeform, Nearby Text, prefixed
  emoji hints, and exact-spelling dictionary in that order with exactly two
  newline characters; absent sections yield `nil`.
- Legacy provider projection retains the same dictionary section.
- It exposes normalized keyword candidates, unprefixed dictionary prompt text,
  and context used by local dictionary/context echo filters.
- Dictionary echo guard applies only to legacy dictionary-in-prompt models;
  `gpt-transcribe` keyword matches remain valid content.
- macOS passes Nearby Text only after its existing Settings/Accessibility gate.
  Composition neither acquires focus text nor weakens iOS bounded-context privacy.

## Runtime-only boundary

- Value is `Equatable`, `Sendable`, and non-Codable.
- Prompt, dictionary, emoji, and Nearby Text are neither persisted nor logged,
  placed in App Group, sent to keyboard, or treated as request journal.
- Multipart, audio, transport, timeout, and cancellation remain adapter work.

## Verification

Cover each source, exact four-source order/separators, disabled/empty inputs,
Nearby Text gating, echo values, `Sendable`, and no Codable consumer contract.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared prompt privacy.
