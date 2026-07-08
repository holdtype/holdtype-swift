# Text Correction

## Goal

Define the optional post-transcription correction stage for HoldType.

Text correction should make dictated text cleaner after transcription without
turning dictation into a rewriting product. The default behavior must preserve
the transcribed wording and avoid a second OpenAI call unless the user turns
model-based correction on.

## Scope

- Settings for post-transcription text correction.
- Local typography cleanup for common AI-looking punctuation artifacts.
- Built-in voice emoji command replacement before user replacement rules.
- User-managed literal search/replace rules.
- Optional OpenAI-powered minimal transcript correction.
- Failure behavior when correction is unavailable or returns unsafe output.
- Handoff of corrected text to last transcript, history, clipboard, and
  automatic insertion.

## Non-goals

- A persistent transcript editor.
- Review-before-insert workflow.
- Automatic learning from corrections in other apps.
- Regex, scripting, or arbitrary code replacement rules.
- Translation, summarization, tone rewriting, or content expansion.
- Live OpenAI calls in normal tests.

## User-visible behavior

- Settings must include a dedicated Text Correction section.
- OpenAI text correction is off by default.
- When OpenAI text correction is off, the app must not make a second OpenAI
  text-generation request after transcription.
- When OpenAI text correction is on, a successful transcription may be sent to
  OpenAI for one additional minimal correction pass before it becomes accepted
  output.
- The default correction model is `gpt-5.5`. The user may choose a cheaper or
  faster model such as `gpt-5.4` or `gpt-5.4-mini`, or enter a custom model.
- The default correction prompt must ask for the smallest possible edits only:
  obvious transcription errors, spacing, capitalization, and punctuation. It
  must explicitly forbid rewriting style, adding facts, removing facts,
  translating, summarizing, or making uncertain changes.
- The correction prompt field should show the standard correction prompt as
  editable text by default, not as a hidden empty override.
- The Text Correction section must provide a Reset action that restores the
  standard correction prompt after the user edits it.
- The correction prompt may be edited or reset while OpenAI correction is off;
  editing the prompt must not enable or trigger the additional OpenAI request.
- OpenAI correction should return only the corrected text, without notes,
  markdown, explanations, alternatives, or diagnostics.
- Local plain-typography cleanup is on by default because it does not consume
  OpenAI resources.
- Local plain-typography cleanup may replace typographic quotes, typographic
  apostrophes, long dash variants, single-character ellipsis, non-breaking
  spaces, and word-joiner characters with plainer informal text equivalents.
- User replacement rules are an ordered list of literal, case-insensitive
  search/replace pairs. They are empty by default.
- Replacement rule search text is matched literally, not as a regular
  expression. The replacement text is inserted exactly as configured.
- Replacement rules with an empty search value must be ignored.
- Built-in emoji command replacement is governed by
  `voice-emoji-commands.md`. When enabled, it runs after local typography
  cleanup and before user replacement rules.
- Local cleanup and user replacement rules run after OpenAI correction when
  OpenAI correction is enabled, and run directly on the transcript when OpenAI
  correction is disabled.
- Translation mode may run one final local plain-typography cleanup pass on the
  translated output as defined in `post-transcription-actions.md`; that final
  pass must not include emoji command replacement or user replacement rules.
- The app's Last Transcript, transcript recovery history, Last Result,
  and automatic insertion receive the final corrected text.
- If correction is disabled or every correction stage is skipped, the accepted
  transcript is the normal transcription result.

## Invariants

- Text correction must never overwrite a previous successful transcript after
  a failed transcription.
- Text correction must fail open: if an optional correction stage fails, times
  out, returns empty text, or returns an unsafe output, the app should preserve
  the successful transcription result.
- OpenAI correction must have an explicit timeout and must never wait
  indefinitely.
- API keys, raw transcript text, correction prompts, replacement rules, and
  provider responses must not appear in default logs.
- Normal tests must use fakes or fixtures and must not call the live OpenAI
  API.
- User replacement rules must be literal text replacements, not executable
  scripts.

## Edge cases and failure policy

- Missing API key blocks OpenAI correction but must not discard the successful
  transcription result.
- Invalid API key, rate limit, network failure, provider failure, timeout, or
  unreadable response should skip OpenAI correction and keep the transcription
  result.
- Empty correction output should be ignored.
- Correction output that is much longer or much shorter than the transcript may
  be treated as unsafe and ignored.
- If local cleanup turns a non-empty transcript into empty text, the app should
  keep the pre-cleanup transcript.
- User replacement rules run in the configured order, so later rules may see
  text changed by earlier rules.
- If multiple replacement rules search for the same text, each enabled rule is
  still applied in order.
- Replacement rule matching ignores source-text capitalization, so one rule can
  replace uppercase, lowercase, and mixed-case instances.

## Route / state / data implications

UserDefaults may store:

- whether OpenAI correction is enabled
- selected correction model
- correction prompt text, defaulting to the standard minimal-correction prompt
- whether local plain-typography cleanup is enabled
- ordered literal replacement rules

Keychain still stores only the OpenAI API key.

OpenAI correction uses the same Keychain API key as transcription but is a
separate request from the audio transcription request.

Usage estimates for audio transcription remain governed by
`openai-transcription.md`; text-correction token accounting requires a future
usage-estimate spec before the Billing section may claim correction costs.

## Verification mapping

- App settings tests should cover defaults, prompt reset, persistence, ignored
  empty replacement rules, and resolved correction model fallback.
- Local cleanup tests should cover dash normalization, quote normalization,
  ellipsis normalization, non-breaking space normalization, ordered
  case-insensitive replacement rules, and empty-output fallback.
- OpenAI correction service tests should cover request construction, output
  parsing, timeout mapping, provider error mapping, and no live API calls.
- Controller tests should cover correction disabled, local cleanup enabled,
  OpenAI correction success, and OpenAI correction failure preserving the raw
  transcript.
- Settings presentation tests should cover the Text Correction navigation item
  and section.

## Unknowns requiring confirmation

- Whether local plain-typography cleanup should remain default-on after
  real-world dictation testing.
- Whether correction usage should appear in the Billing estimate.
- Whether future presets should expose style modes beyond minimal correction.
