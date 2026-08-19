# Post-Transcription Actions

- Node type: hybrid
- Contract ID: `holdtype.macos.post-transcription-actions`
- Domain ID: `holdtype.macos.post-transcription-actions`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.post-transcription-actions@1`
- Read when: translation-mode dictation intent, route configuration, provider translation, or strict failure is in scope.
- Do not read when: only ordinary dictation, immediate Text Fixes, or correction internals is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

An optional shortcut-carried intent runs one configured OpenAI translation
after successful transcription and fail-open correction/local cleanup, before
final accepted output.

## Non-goals

- Automatic source detection, review-before-insert, chained actions, immediate
  selected-text/Draft Fixes, or live OpenAI in normal tests.

## Children

- [Settings and preflight](post-transcription-actions/settings-and-preflight.md) — shortcut intent, languages, model, prompt, and readiness.
- [Runtime translation request](post-transcription-actions/runtime-translation-request.md) — captured snapshot and narrow provider boundary.
- [Translation result and failure](post-transcription-actions/result-and-failure.md) — ordering, strict failure, cancellation, output, and verification.

## Shared invariants

- Translation never runs after failed/empty transcription.
- Failure/cancellation never silently inserts or saves untranslated text as translated success.
- Timeout and cancellation stop actual transport boundedly; late responses are ignored.
- Previous accepted transcript survives failure.
- Default logs contain no credential, source text, prompt, or provider response.
- Normal tests use fakes, never live OpenAI.

## Dependencies

- [OpenAI transcription](openai-transcription.md) — accepted source text.
- [Text correction](text-correction.md) — preceding fail-open stage.

## State

UserDefaults stores enablement, source behavior/override, target, model, and
prompt; Keychain stores only shared OpenAI key. Session carries output intent.
