---
id: VT-167
status: done
priority: P1
lane: transcription
dependencies:
allowed_paths:
  - backlog/vt-167-text-correction-settings-and-pipeline.md
  - docs/specs/features/text-correction.md
  - docs/specs/features/openai-transcription.md
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/text-output-workflow.md
  - docs/specs/features/privacy-and-permissions.md
  - VibeType/**
  - VibeTypeTests/**
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - git diff --check
---

# VT-167 - Text Correction Settings And Pipeline

Status: done
Priority: P1
Lane: transcription
Dependencies: none
Expected outputs: text-correction spec, settings UI, post-transcription correction pipeline, tests
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; git diff --check

## Goal

Add an opt-in text correction stage after OpenAI transcription and before
accepted transcript output. The stage should support optional OpenAI-powered
minimal correction plus local de-AI typography cleanup and simple search/replace
rules.

## Scope

- Create the product spec for text correction behavior.
- Add local settings for OpenAI correction, correction model, local cleanup, and
  literal replacement rules.
- Add a dedicated Settings sidebar section for correction controls.
- Implement local text normalization based on the existing de-AI writing skill's
  informal typography cleanup.
- Implement an OpenAI text correction service with bounded timeout and
  fail-open behavior.
- Wire the correction stage into the accepted transcript flow.
- Add focused unit tests for settings, local cleanup, OpenAI request/response
  handling, and controller fallback behavior.

## Non-goals

- Live OpenAI calls in tests.
- Persistent transcript editing UI.
- Automatic learning from user edits in other apps.
- Regex replacement rules.
- Provider abstraction beyond OpenAI.

## Acceptance

- Text correction settings are persisted with safe defaults.
- OpenAI correction is off by default and does not add a second API call unless
  enabled.
- Local cleanup can normalize common AI-looking typography artifacts.
- Correction failures preserve the successful raw transcript.
- Accepted transcript history, clipboard, and insertion receive the final
  corrected text.

## Notes

- Follow `docs/specs/features/openai-transcription.md`.
- Follow `docs/specs/features/text-output-workflow.md`.
- Keep default logs free of transcript text and provider payloads.

## Completion Notes

- Added the text-correction spec, persisted settings, Settings UI section,
  local cleanup rules, OpenAI correction client, and accepted-transcript
  pipeline integration.
- Added focused tests for settings persistence, local cleanup, OpenAI correction
  request handling, and correction fallback in the dictation controller.
- Verified Settings opens from the menu bar app and the Text Correction section
  exposes the expected OpenAI correction, model, prompt, local cleanup, and
  replacement-rule controls.
