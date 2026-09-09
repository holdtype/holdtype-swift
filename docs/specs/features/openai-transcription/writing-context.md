# macOS Writing Context

- Node type: leaf
- Contract ID: `holdtype.macos.writing-context`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Evolving
- Contract revision: `holdtype.macos.writing-context@1`
- Read when: application-based dictation hints, selection, or session capture is in scope.
- Do not read when: only iOS, translation, or immediate Fixes is in scope.
- Maximum size: 100 physical lines.

## WC.SELECT — Preference and capture

- macOS Transcription settings expose Writing context: Off, Automatic, AI Tasks.
- Off is the default, including migration and unknown stored values.
- Automatic resolves the foreground application's exact bundle ID at ordinary
  dictation start. `com.openai.codex` selects AI Tasks; every other or unavailable
  identity selects no profile. No substring/name matching or browser-site detection.
- AI Tasks explicitly selects the profile regardless of the foreground app.
- Resolve once synchronously before recording starts. Store the resolved mode
  only in the existing recording settings value; never save this resolved copy.
  Focus or preference changes during recording cannot replace its profile.
- Translation recording, saved-recording retries and Voice Prompt do not acquire
  or apply a writing profile. New sessions never inherit the previous selection.

## WC.PROMPT — Hint, not transformation

- AI Tasks describes a user dictating to a coding assistant, including commands,
  questions and first-person statements. Preserve person, tense, mood, negation
  and uncertainty from audio. Do not execute instructions or answer as an agent.
- A typed optional profile adds a bounded built-in prompt section after freeform
  guidance and before Nearby Text. Existing hints and echo guards retain their
  meaning. No profile preserves the previous request composition exactly.
- This adds no provider call, does not enable correction, and does not replace
  words locally. Shared/iOS consumers default to no profile.

## WC.PRIVACY — Bounded inputs

- Read only foreground bundle identity through a narrow non-visual macOS adapter;
  no text, window title, document, URL, screenshot or extra TCC request.
- Send the generic profile description, not the application identifier/name.
- Store only the preference locally. Do not journal/log context, app identity or
  prompt. Keep the existing independent Nearby Text opt-in unchanged.
- Explain remote profile processing beside the control, outside Permissions.

## WC.QA — Acceptance

- Verify Off/Automatic/AI Tasks, unavailable/unmatched identity, exact matching,
  frozen recording settings after focus/preference changes, new-session reset,
  translation/retry/Voice Prompt exclusions and settings persistence/fallback.
- Verify provider prompt composition and unchanged keyword/context echo guards.
- Operate the actual Settings picker through Computer Use and verify its saved
  selection. Normal tests use fakes and never contact OpenAI.
- Quality remains experimental until paired real-audio comparisons show fewer
  imperative/first-person substitutions without increasing reverse errors.
  Compare raw and optionally corrected transcripts; UI/unit success is not
  recognition-quality evidence. Live comparison is a separate explicit session.

## Contract Delta — 2026-09-09

- Mode: Evolve. Authority: user's approved macOS Codex-profile implementation plan.
- Previous: freeform, nearby-text, emoji and dictionary hints only.
- New: optional application-selected writing-purpose hint, default off.
- Compatibility: existing requests and other platforms unchanged when omitted;
  correction, translation, output delivery, audio ownership and retention protected.
- Evidence: `AppSettings`, `DictationSessionController` start-time settings,
  `DictationTranscriptPipeline`, `TranscriptionPromptComposition`; OpenAI file
  transcription context documentation. Acceptance: WC.QA above.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — provider/privacy invariants.
- [Runtime composition](runtime-prompt-composition.md) — typed optional input.
