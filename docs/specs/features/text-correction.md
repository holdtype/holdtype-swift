# Text Correction

- Node type: hybrid
- Contract ID: `holdtype.shared.text-correction`
- Domain ID: `holdtype.shared.text-correction`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; iOS scope governed by current iOS contracts
- Contract revision: `holdtype.shared.text-correction@1`
- Read when: optional OpenAI correction, local typography, emoji commands, replacement rules, or corrected-text handoff is in scope.
- Do not read when: only translation, immediate Text Fixes, or provider transcription is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Optional correction cleans transcription without rewriting it. Local cleanup
defaults on; a second OpenAI request defaults off. The pipeline owns minimal
correction, typography, emoji commands, ordered literal replacements, fail-open
safety, iOS Library editing, and final corrected-text handoff.

## Non-goals

- Persistent editor, review-first workflow, auto-learning, regex/scripts,
  translation/summarization/style expansion, immediate Fixes, or live API tests.

## Children

- [Settings and local pipeline](text-correction/settings-and-local-pipeline.md) — defaults, prompt/model, typography, emoji, replacements, and output.
- [iOS Replacement Library](text-correction/ios-replacement-library.md) — list/detail UX, raw fields, status, search, reorder, and atomic actions.
- [Runtime request and failure](text-correction/runtime-request-and-failure.md) — narrow provider boundary, timeout/cancellation, unsafe output, and fail-open behavior.
- [Storage and verification](text-correction/storage-and-verification.md) — macOS/iOS repositories, concurrency, persistence, and acceptance coverage.

## Shared invariants

- Correction never overwrites prior success after failed transcription.
- Every optional correction failure, timeout, cancellation, empty, or unsafe
  result fails open to accepted transcription unless the whole session is cancelled.
- User replacements are literal ordered text, never executable scripts.
- Credentials, transcript, prompt, rules, and provider response never enter default logs.
- Normal tests use fakes, never live OpenAI.

## Dependencies

- [OpenAI transcription](openai-transcription.md) — accepted input text.
- [Voice emoji commands](voice-emoji-commands.md) — built-in replacement semantics.

Translation's final typography reuse remains governed by
`post-transcription-actions.md` without creating a reverse dependency.

## Unknowns

- Revalidate default-on typography and any future style presets with real usage.
