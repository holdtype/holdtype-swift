---
id: VT-185
status: done
priority: P0
lane: settings
dependencies:
allowed_paths:
  - backlog/vt-185-translation-follow-transcription-source.md
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

# VT-185 - Translation Follows Transcription Source

Status: done
Priority: P0
Lane: settings
Dependencies: none
Expected outputs: translation source follows transcription by default, target language is explicitly configured, specs/tests updated
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build; git diff --check

## Goal

Remove personal hardcoded translation direction defaults. Translation should
default to translating the transcript produced by the normal transcription
settings, with the target language explicitly configured by the user.

## Scope

- Change translation source behavior so the default source follows the normal
  transcription language setting, including Auto.
- Keep an optional explicit source-language override for users who need it.
- Change target language defaults so new installs do not silently choose a
  personal target language.
- Require a valid target language before the translation request can run.
- Adjust OpenAI translation instructions so source language is optional when
  transcription language is Auto.
- Preserve migration for the legacy Russian-to-English shortcut.
- Update Settings UI copy and tests.

## Non-goals

- Live OpenAI calls in tests.
- Automatic target-language detection.
- Billing/token estimates for translation requests.
- Full shortcut editing UI.

## Acceptance

- New default translation source mode is same as transcription.
- New default translation target is unconfigured, while the shortcut remains
  off by default.
- Translation mode does not override transcription language unless the user
  explicitly chooses a source-language override.
- OpenAI translation prompt construction omits a source language when the
  source follows Auto transcription.
- Existing legacy Russian-to-English shortcut settings still migrate to a
  working Russian-to-English configuration.
- Tests cover defaults, persistence, prompt construction, controller behavior,
  and migration.

## Completion

- Changed translation source defaults to Same as Transcription, with an
  explicit source-language override available only when selected.
- Changed new default target language to unconfigured, so translation cannot
  run until the user chooses a target.
- Updated OpenAI translation instructions to omit source language when
  transcription source is Auto.
- Changed enabled translation sessions with incomplete translation settings to
  fail visibly without output instead of silently inserting untranslated text.
- Preserved migration for legacy Russian-to-English shortcut settings and
  enabled previously saved source-language configurations.
- Verification:
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
  - `git diff --check`
- Runtime QA: blocked. The available UI automation tools in this session were
  simulator-only and not applicable to the changed macOS Settings surface.
