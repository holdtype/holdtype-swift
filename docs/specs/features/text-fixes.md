# Text Fixes

- Node type: hybrid
- Contract ID: `holdtype.shared.text-fixes`
- Domain ID: `holdtype.shared.text-fixes`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; iOS release gates remain in current iOS contracts
- Contract revision: `holdtype.shared.text-fixes@3`
- Read when: immediate Translate, Correct Text, custom Fixes, macOS Fixes palette, iOS Voice Fixes, keyboard Fixes, or Voice Prompt is in scope.
- Do not read when: only automatic post-transcription correction or translation is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Transform a non-empty selection or, where safely supported, the complete
compatible text field or confirmed Voice Draft through a reusable Fix. The
same catalog concept spans macOS, iOS Voice, and HoldType Keyboard while each
platform keeps its honest target and provider boundary.

Scope includes typed Translate and Correct Text, custom prompts and profiles,
local catalog management, macOS `Option+J`, transient Voice Prompt, iOS Voice
and keyboard presentation, provider processing, replacement, privacy, and
failure. It excludes automatic rewriting, chained actions, catalog sync,
clipboard/secure-field fallbacks, per-action credentials, and History Fixes.

## Children

- [Catalog and profiles](text-fixes/catalog-and-profiles.md) — built-ins, custom records, validation, ordering, migration, and recency.
- [Targets, processing, and replacement](text-fixes/targets-processing-and-replacement.md) — capture, provider routing, exact output, stale checks, Undo, and failure.
- [macOS Voice Prompt](text-fixes/voice-prompt.md) — transient instruction recording, two provider stages, recovery, and protected sinks.
- [macOS palette and editor](text-fixes/macos-palette-and-editor.md) — shortcut, palette/dialog, Manage Fixes, autosave, and built-in details.
- [iOS Voice and keyboard](text-fixes/ios-voice-and-keyboard.md) — Draft replacement, extension UI, bounded handoff, Full Access, and release gate.
- [Privacy, state, and verification](text-fixes/privacy-state-and-verification.md) — consent, storage, logs, failures, invariants, and evidence.

## Shared invariants

- A Fix never overwrites outside its captured target; stale or uncertain
  targets remain unchanged and keyboard processing requires a non-empty selection.
- Catalog Fixes never start recording. Only macOS `Voice Prompt…` owns a
  mutually exclusive Fix recording.
- The keyboard extension never reads Keychain or contacts OpenAI.
- External work has bounded timeout and real cancellation; automated tests use fakes.
- Immediate Fix success does not mutate Latest, Pending, History, Recording
  Cache, or transcription usage.

## Dependencies and precedence

- [Built-in writing skill](text-fixes-writing-skill.md) — narrow macOS custom-Fix extension; wins only for that option.
- [OpenAI transcription](openai-transcription.md) — Voice Prompt audio stage.
- [Text correction](text-correction.md) and `post-transcription-actions.md` — typed Correct Text and Translate routes.

More-specific current iOS release, Voice, keyboard-handoff, settings, privacy,
and persistence contracts retain precedence. Revision 3 adds only Voice Prompt
under `TF-DELTA-R3-VOICE-PROMPT`; all prior catalog and platform behavior stays protected.
