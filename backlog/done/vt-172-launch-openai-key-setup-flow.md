---
id: VT-172
status: done
priority: P1
lane: settings
dependencies:
allowed_paths:
  - docs/specs/features/privacy-and-permissions.md
  - docs/specs/features/settings-and-secret-storage.md
  - VibeType/Models/**
  - VibeType/Services/**
  - VibeType/Settings/**
  - VibeType/SettingsView.swift
  - VibeType/MenuBarView.swift
  - VibeTypeTests/**
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-172 - Launch OpenAI Key Setup Flow

Status: done
Priority: P1
Lane: settings
Dependencies: none
Expected outputs: spec updates, compact OpenAI setup window, launch and recording preflight tests
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build; git diff --check

## Goal

Show a compact OpenAI API key setup window after required permissions are
complete, without mixing key setup into the Required Permissions window.

## Scope

- Update product specs for the ordered setup flow.
- Keep Required Permissions focused only on system permissions.
- Add a compact OpenAI setup surface that reuses the existing OpenAI key UI.
- Check missing API key after permissions are ready on launch and before
  recording starts.
- Add tests for setup ordering and missing-key preflight behavior.

## Non-goals

- Redesign full Settings.
- Validate the OpenAI key with a live OpenAI request.
- Change Keychain storage semantics or log API keys.
- Change microphone, Accessibility, or Input Monitoring permission semantics.

## Acceptance

- Launch setup shows permissions first when any required permission is missing.
- Launch setup shows OpenAI key setup only when required permissions are ready
  and no API key is saved.
- Launch setup shows nothing when permissions and API key are ready.
- Recording attempts use the same priority: permissions first, then OpenAI key.
- The Required Permissions window still does not display OpenAI key setup.

## Notes

- Related specs: `privacy-and-permissions.md`,
  `settings-and-secret-storage.md`.

## Verification

- PASS: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- PASS: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- PASS: `git diff --check`

## Runtime QA

- Runtime QA: required
- Tool: Computer Use
- Scenario: launch freshly built VibeType app with current local setup state.
- Actions: launched the Debug `VibeType.app` from the current DerivedData path
  and inspected the key window by full app path.
- Expected: required permission blockers show the compact Required Permissions
  window first, without OpenAI API key setup content.
- Observed: `VibeType Required Permissions` opened with Secure Storage,
  Microphone, and Accessibility rows only. OpenAI key setup was not shown while
  permissions still needed attention.
- Result: PASS
- Evidence: Computer Use accessibility tree and screenshot from the runtime
  smoke in this task-solving session.
