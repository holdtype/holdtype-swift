---
id: VT-170
title: Accessibility Permission Request Flow
status: done
priority: P1
lane: permissions
dependencies:
  - VT-149
allowed_paths:
  - docs/specs/features/privacy-and-permissions.md
  - VibeType/Services/PermissionsService.swift
  - VibeType/MenuBarPresentation.swift
  - VibeType/MenuBarView.swift
  - VibeType/SettingsView.swift
  - VibeType/Settings/PrivacyPermissionsSettingsSection.swift
  - VibeType/Settings/SetupPermissionsViewModel.swift
  - VibeTypeTests/PermissionsServiceTests.swift
  - VibeTypeTests/MenuBarPresentationTests.swift
  - VibeTypeTests/SetupPermissionsViewModelTests.swift
  - backlog/vt-170-accessibility-permission-request-flow.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - git diff --check
---

# VT-170 - Accessibility Permission Request Flow

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-149
Expected outputs: spec update, Accessibility request action repair, fake-backed tests
Verification: `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`; `git diff --check`

## Goal

Repair the Required Setup and Settings Accessibility action so users are not
sent to an empty System Settings list without a clear next step.

## Scope

- Update the privacy/permissions spec to require an active Accessibility trust
  request before or alongside the System Settings deep link.
- Make the Accessibility action call the macOS trust-prompt API before opening
  the Accessibility pane.
- Explain the manual fallback when VibeType is not listed: add it with `+`,
  then enable it.
- Keep the change scoped to Accessibility permission UI and service behavior.

## Acceptance Criteria

- The missing Accessibility state no longer exposes only a passive
  "open settings" action.
- Menu, Settings, and Required Setup actions use the same request-first
  behavior.
- Fake-backed tests prove the request path uses the prompting Accessibility
  check and then opens System Settings when trust is still missing.
- The task is marked done only after verification is recorded.

## Result

- Updated the permission spec to require a request-first Accessibility action
  and a manual `+` fallback when VibeType is not listed.
- Updated the Accessibility service and visible permission actions to call the
  prompting trust check before opening System Settings.
- Added setup and permission service tests for the request-first path.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- Passed: `git diff --check`
- Tooling: `xcodebuild` fallback after MCP discovery exposed no macOS test
  runner in this session.
- Runtime QA: blocked. The available Computer Use surface was click-only and
  there was no safe macOS UI snapshot/readback tool for the changed setup
  text; the real Accessibility request remains a user-controlled system
  privacy action.
