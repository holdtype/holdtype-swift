# Correction Settings and Local Pipeline

- Node type: leaf
- Contract ID: `holdtype.shared.text-correction.pipeline`
- Domain ID: `holdtype.shared.text-correction`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.text-correction.pipeline@1`
- Read when: correction defaults, prompt/model, typography, emoji, replacements, or final corrected text is in scope.
- Do not read when: only iOS Library editing or remote cancellation mechanics is in scope.
- Maximum size: 100 physical lines.

## Remote correction settings

- Dedicated Text Correction section; OpenAI correction defaults off and makes
  no second request while off.
- When on, one minimal correction pass may precede accepted output.
- Default model `gpt-5.5`; choices may include `gpt-5.4`, `gpt-5.4-mini`, or custom.
- Editable default prompt asks smallest obvious transcription, spacing,
  capitalization, and punctuation fixes and forbids style rewrite, facts
  add/remove, translation, summary, or uncertain change.
- Prompt displays standard text, is editable/resettable while off, and editing
  never enables or triggers provider work.
- Provider returns corrected text only, no notes/Markdown/alternatives/diagnostics.

## Local pipeline

- Plain typography defaults on and may normalize typographic quotes/apostrophes,
  long dashes, single ellipsis, non-breaking spaces, word joiners, and repeated spacing.
- Built-in emoji replacement follows typography and precedes user rules.
- User rules default empty and apply literal case-insensitive search/replacement
  in configured order; later/duplicate searches see earlier changes.
- Empty/whitespace Search is ignored; Replacement is inserted exactly, including
  empty removal or whitespace-only text.
- With OpenAI on, local pipeline follows correction; otherwise it runs directly on transcript.
- If local processing becomes empty, preserve previous non-empty fallback;
  otherwise final normalization trims only outer whitespace/newlines.
- Translation may reuse typography once after translation but never emoji/rules.

## Accepted output and immediate Fix

- Last Transcript, History, Last Result, and insertion receive final corrected text.
- If all stages disabled/skipped, accepted output is transcription.
- Immediate Fix may force saved model/prompt for one target without changing
  automatic correction or dictation/Latest/History/usage state.
- Successful correction token counts may create local text-usage event without text-state changes.

## Dependencies

- [Text correction](../text-correction.md) — shared fail-open invariants.
