---
id: VT-168
status: done
priority: P1
lane: transcription
dependencies:
allowed_paths:
  - backlog/vt-168-text-correction-default-prompt-reset.md
  - docs/specs/features/text-correction.md
  - docs/specs/features/settings-and-secret-storage.md
  - VibeType/Models/AppSettings.swift
  - VibeType/Settings/TextCorrectionSettingsSection.swift
  - VibeTypeTests/AppSettingsTests.swift
  - VibeTypeTests/OpenAITextCorrectionServiceTests.swift
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - git diff --check
---

# VT-168 - Text Correction Default Prompt Reset

Status: done
Priority: P1
Lane: transcription
Dependencies: none
Expected outputs: text-correction spec update, default prompt persistence, Settings reset action, tests
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; git diff --check

## Goal

Make the Text Correction prompt field contain the standard default correction
prompt by default, while keeping it user-editable and providing a Reset action
that restores the standard prompt.

## Scope

- Update the text-correction behavior contract.
- Persist the default prompt as the normal setting value instead of treating an
  empty field as the primary default state.
- Add a Settings reset action for the correction prompt.
- Add focused settings tests for default prompt persistence and reset behavior.

## Non-goals

- Changing the correction model defaults.
- Changing OpenAI request shape.
- Adding prompt presets beyond the single standard prompt reset.

## Completion Notes

- Text Correction now uses the standard minimal-correction prompt as the
  default editable prompt value.
- The Settings prompt field exposes a Reset action that restores the standard
  prompt and stays available for editing while OpenAI correction is off.
- Blank or whitespace-only persisted correction prompts load the standard
  prompt instead of showing an empty field.

## Verification

- PASS: `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- PASS: `git diff --check`
- NOTE: Runtime Settings UI launch was attempted against the debug app, but
  macOS accessibility automation did not open the status-menu Settings window
  in this session; the view structure and settings behavior are covered by the
  focused tests above.
