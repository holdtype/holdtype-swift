# Post-Transcription Actions

## Goal

Define optional actions that may run after a successful transcription before
HoldType accepts and outputs final text.

The first action is a configurable OpenAI translation mode for dictation
started with a dedicated shortcut.

## Scope

- Shortcut-triggered post-transcription output intent.
- OpenAI translation after transcription.
- Settings for enabling the translation shortcut.
- Settings for translation source behavior, target language, model, and prompt.
- Handoff ordering with text correction, Last Transcript, history, clipboard,
  and automatic insertion.
- Failure behavior for translation requests.

## Non-goals

- Automatic language detection for translation mode.
- Review-before-insert UI.
- Chained action editing, scripting, templates, summaries, or tone rewriting.
- Live OpenAI calls in normal tests.

## User-visible behavior

- The normal `Right Command` hold shortcut keeps the existing dictation
  behavior and outputs the final transcript in the transcription language.
- Settings may expose a special `Right Command+Option` hold shortcut mode that
  translates the accepted transcript to the configured target language after
  transcription.
- The special translation shortcut is enabled by default. Translation still
  requires a configured target language before HoldType can make the additional
  OpenAI text request after transcription.
- Starting a translation-mode session with an unconfigured target language or
  invalid source override should fail immediately, show a user-visible error,
  and open Settings focused on Translation so the user sees the language warning.
  This recovery opening should not place keyboard focus into the translation
  model or prompt text fields.
- If an active normal recording is promoted to translation before stop, HoldType
  should stop the recording, fail before transcription or translation requests
  when translation languages are not configured, and focus Settings on
  Translation.
- The Translation Settings section should include source behavior, target
  language, translation model, and an editable translation prompt with a Reset
  action.
- Translation source behavior should default to Same as Transcription. In this
  mode, translation uses the transcript produced by the normal transcription
  settings and must not override the transcription language.
- If the normal transcription language is Auto, OpenAI translation instructions
  should omit a source-language code and translate the transcript as written.
- Translation source behavior may provide an explicit source-language override
  for users who need it. Source override choices should include common preset
  language codes plus Custom.
- Target language choices should include common preset language codes plus
  Custom.
- New installs should not silently default to a personal target language. The
  target language should start unconfigured.
- If the target language is unconfigured or invalid, or if an explicit source
  override is invalid, a translation-mode session must fail visibly before
  output delivery and must not make transcription or translation requests when
  the invalid configuration is known before those requests.
- If translation mode is disabled, the special shortcut must behave like normal
  dictation.
- Translation runs after successful transcription and after the existing
  optional text-correction and local cleanup stages.
- When local plain-typography cleanup is enabled, successful translation output
  receives one final local typography cleanup before it becomes accepted text.
  This final pass must not rerun OpenAI correction, emoji command replacement,
  or user replacement rules.
- The final translated text becomes the accepted output text. Last Transcript,
  recovery history, Last Result, and automatic insertion use the final
  translated text.
- Translation should return only the translated text, without notes,
  markdown, explanations, alternatives, diagnostics, or source text.
- The translation prompt should be editable even when the translation shortcut
  is off, so the user can prepare settings before enabling the shortcut.
- A blank or whitespace-only translation prompt should fall back to HoldType's
  default translation prompt.

## Invariants

- Translation must never run after a failed or empty transcription.
- Translation must never overwrite a previous successful transcript after a
  failed transcription.
- Translation failure must not silently insert or save the untranslated
  transcript as if the special translation action succeeded.
- The translation request must have an explicit timeout and must never wait
  indefinitely.
- API keys, raw transcript text, translation prompts, and provider responses
  must not appear in default logs.
- Normal tests must use fakes or fixtures and must not call the live OpenAI API.

## Edge cases and failure policy

- Missing API key, invalid API key, rate limit, network failure, provider
  failure, timeout, unreadable response, or empty translation should fail the
  current translation-mode session visibly.
- If translation fails, the previous Last Transcript remains intact and no
  output delivery or recovery-history write occurs for the failed session.
- If text correction fails before translation, correction follows its existing
  fail-open policy and translation receives the accepted transcription text.
- If final typography cleanup would produce empty translated output, the app
  should keep the pre-cleanup translation result.
- If translation succeeds but automatic insertion fails, the translated text
  remains accepted and recoverable under the normal text-output workflow.
- If the shortcut key-up arrives without a matching translation-mode recording,
  it must not create an output action.
- If translation configuration failure opens Settings, the recovery action
  should target the Translation section rather than the OpenAI API key or
  Transcription sections.

## Route / state / data implications

UserDefaults may store:

- whether the translation shortcut is enabled
- translation source behavior
- translation source language override selection
- custom translation source language code
- translation target language selection
- custom translation target language code
- translation model
- translation prompt

Keychain still stores only the OpenAI API key.

Translation uses the same Keychain API key as transcription but is a separate
OpenAI text request from the audio transcription request.

The active dictation session state must carry an output intent so the
recording-start event can determine whether the stopped session should produce
normal output or translated output.

Usage estimates for audio transcription remain governed by
`openai-transcription.md`; translation token accounting requires a future
usage-estimate spec before the Billing section may claim translation costs.

## Verification mapping

- App settings tests should cover the default-on setting and persistence.
- Hotkey tests should cover carrying translation intent from key down to the
  matching key up.
- App settings tests should cover language preset resolution, custom code
  validation, default prompt reset, and legacy Russian-to-English setting
  migration.
- Controller tests should cover successful translation output, disabled
  translation falling back to normal output, invalid translation settings
  failing visibly without output, final translation typography cleanup without
  replacement rules, and translation failure preserving the previous accepted
  transcript.
- OpenAI translation service tests should cover request construction, output
  parsing, timeout mapping, provider error mapping, and no live API calls.

## Unknowns requiring confirmation

- Whether Billing should estimate text translation costs.
