---
id: VT-177
status: done
priority: P0
lane: settings
dependencies:
allowed_paths:
  - backlog/vt-177-configurable-translation-settings.md
  - docs/specs/features/post-transcription-actions.md
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/global-hotkey.md
  - docs/specs/features/privacy-and-permissions.md
  - docs/specs/features/text-output-workflow.md
  - VibeType/**
  - VibeTypeTests/**
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-177 - Configurable Translation Settings

Status: done
Priority: P0
Lane: settings
Dependencies: none
Expected outputs: configurable translation Settings panel, spec updates, tests, verification result
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build; git diff --check

## Goal

Replace the hardcoded Russian-to-English translation shortcut behavior with a
configurable OpenAI translation settings surface.

## Scope

- Update specs for configurable source language, target language, model, and
  editable translation prompt.
- Keep the Option+Right Command translation shortcut available and off by
  default.
- Add a dedicated Translation Settings sidebar item and form.
- Expand supported language presets for transcription and translation, with a
  custom language code option.
- Persist non-secret translation settings in UserDefaults while keeping the
  OpenAI API key in Keychain.
- Use the configured OpenAI translation model and prompt for the translation
  request.
- Preserve fail-closed translation behavior.

## Non-goals

- Live OpenAI calls in tests.
- Billing/token estimates for translation requests.
- Full shortcut editing UI.
- Review-before-insert translation UI.

## Acceptance

- Settings exposes Translation separately from Shortcut.
- Translation settings include enable toggle, source language, target language,
  model, editable prompt, and Reset prompt action.
- Translation no longer hardcodes Russian-to-English in the request prompt or
  controller eligibility.
- Existing saved Russian-to-English shortcut setting migrates to the new
  translation shortcut setting.
- Tests cover defaults, persistence, request prompt construction, controller
  behavior, and shortcut intent handoff.

## Notes

- Relevant specs: `docs/specs/features/post-transcription-actions.md`,
  `docs/specs/features/settings-and-secret-storage.md`,
  `docs/specs/features/global-hotkey.md`,
  `docs/specs/features/privacy-and-permissions.md`.
- Existing implementation entry points: `AppSettings`,
  `KeyboardShortcutSettingsSection`, `SettingsNavigationItem`,
  `SettingsDetailView`, `DictationSessionController`,
  `OpenAITextTranslationService`, and translation-related tests.

## Completion

- Added configurable Translation settings for shortcut enablement, source
  language, target language, model, prompt editing, and prompt reset.
- Expanded preset language codes while preserving custom language code entry.
- Replaced hardcoded Russian-to-English request instructions with configured
  OpenAI translation instructions.
- Migrated the legacy Russian-to-English shortcut setting to the new
  translation shortcut setting.
- Verification:
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
  - `git diff --check`
- Runtime QA: blocked. Computer Use screenshot/snapshot access for the changed
  macOS Settings surface was not available in this session; the available
  XcodeBuildMCP UI tools were simulator-only and not applicable to the macOS
  menu bar app.
