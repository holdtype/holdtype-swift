# Transcription Prompt, Dictionary, and Nearby Context

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.prompt`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.prompt@1`
- Read when: freeform prompt, dictionary, emoji hints, nearby text, or echo rejection is in scope.
- Do not read when: only audio transport, credential, timeout, or response parsing is in scope.
- Maximum size: 100 physical lines.

## Prompt and keywords

- Trimmed non-empty freeform prompt is optional user content and is not logged.
- `gpt-transcribe` context order is freeform prompt, nearby active text,
  built-in emoji hints, then exact-spelling dictionary guidance.
- Each normalized dictionary term is also one `keywords[]` field after trimming
  and duplicate removal. Terms are literal hints, relevant only, and not output guarantees.
- A keyword is one line and contains no `<`, `>`, CR, or LF. Unsuitable legacy
  entries are omitted rather than forming an invalid request.
- Legacy models retain dictionary-in-prompt compatibility.
- Emoji hints are included only when enabled with an active command set.

## Nearby context and privacy

- When enabled, HoldType may best-effort read a short excerpt near the cursor
  from the focused editable field for continuity.
- Missing Accessibility, secure/noneditable/empty fields continue without that
  excerpt. No full-document or unrelated content is read.
- Dictionary appears in both exact-spelling prompt guidance and keyword fields
  so spoken terms may emit configured spelling across scripts.

## Echo rejection

- Legacy prompt compatibility rejects output consisting only/almost only of the
  dictionary hint. `gpt-transcribe` does not reject output merely because it
  equals a keyword.
- Output copied only from nearby active text is rejected as new dictation.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared privacy and acceptance rules.
