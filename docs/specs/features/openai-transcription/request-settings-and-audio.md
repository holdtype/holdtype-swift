# Transcription Request Settings and Audio Validation

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.request`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.request@1`
- Read when: model, language, file eligibility, multipart field order, or response-size limits are in scope.
- Do not read when: only prompt composition, transport cleanup, or recovery UI is in scope.
- Maximum size: 100 physical lines.

## Settings and file eligibility

- Default model is local setting `gpt-transcribe`. Blank/missing/fresh values
  use the current default; a non-blank saved value is never rewritten. Provider
  model rejection is a settings error, not silent provider substitution.
- MVP source is an existing regular `m4a` or `wav`, non-empty and strictly less
  than 25,000,000 bytes.
- The exact file must pass supported-audio decoder validation; extension,
  header, bytes, and metadata alone are insufficient. Renamed text, header-only,
  truncated, malformed, and undecodable input never reaches OpenAI.
- Multipart reads audio in chunks no larger than 64 KiB and never loads the
  complete file into memory.

## Form contract

- Default field order is `model`, `response_format`, optional `languages[]`,
  optional `prompt`, zero or more `keywords[]`, then `file`.
- Provider filename is controlled as `recording.m4a` or `recording.wav`; local
  filename is never sent.
- `gpt-transcribe` uses plural `languages[]`: Auto sends none, English `en`,
  Russian `ru`, selected/custom one normalized code. It never uses singular
  `language` for this model.
- Custom language is a validated two- or three-letter ISO-639-style code;
  empty becomes Auto and invalid non-empty input blocks before upload.
- Explicit legacy models may retain singular `language` and dictionary-in-prompt compatibility.
- Non-audio multipart bytes are capped at 1 MiB; complete size uses overflow
  checking. Oversized metadata is a settings failure, not audio failure.
- Foreground response data is capped at 1 MiB; larger declared or streamed data
  is cancelled as unreadable response.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared provider invariants.
