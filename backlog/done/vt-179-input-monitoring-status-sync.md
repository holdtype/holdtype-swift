---
id: VT-179
status: done
priority: P0
lane: permissions
dependencies:
allowed_paths:
  - backlog/vt-179-input-monitoring-status-sync.md
  - docs/specs/features/menu-bar-app-shell.md
  - docs/specs/features/privacy-and-permissions.md
  - VibeType.xcodeproj/project.pbxproj
  - VibeType/MenuBarPresentation.swift
  - VibeType/MenuBarView.swift
  - VibeType/Services/PermissionsService.swift
  - VibeType/Settings/SetupPermissionsViewModel.swift
  - VibeType/Settings/PermissionsSettingsSection.swift
  - VibeTypeTests/MenuBarPresentationTests.swift
  - VibeTypeTests/PermissionsServiceTests.swift
  - VibeTypeTests/PermissionsSettingsSectionVisibilityTests.swift
  - VibeTypeTests/SetupPermissionsViewModelTests.swift
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-179 - Input Monitoring Status Sync

Status: done
Priority: P0
Lane: permissions
Dependencies: none
Expected outputs: menu bar Input Monitoring status, corrected settings status refresh, tests, verification result
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build; git diff --check

## Goal

Make Input Monitoring permission state visible and consistent across the
Settings permissions pane and the menu bar popover.

## Scope

- Add Input Monitoring status and recovery action to the main menu bar popover.
- Keep full Settings and compact Required Permissions visibility behavior
  consistent for optional Input Monitoring.
- Refresh Input Monitoring status after user actions so a newly enabled
  System Settings checkbox is reflected when macOS reports it.
- Keep the macOS bundle identifier stable so existing Input Monitoring grants
  apply to the running app identity.

## Non-goals

- Do not change hotkey registration behavior.
- Do not make Input Monitoring a required recording blocker.
- Do not touch translation settings or unrelated dirty files.

## Acceptance

- Menu bar presentation exposes Input Monitoring status and actions.
- Allowed Input Monitoring renders as allowed in both Settings and menu
  presentation.
- Existing `potapenko.VibeType` TCC grants continue to match the app
  bundle identity while UI naming remains `VibeType`.
- Optional Input Monitoring remains hidden from compact required-permission
  setup when completed rows are suppressed.

## Completion

- Added Input Monitoring status, detail copy, and recovery action to the menu
  bar popover presentation and view.
- Switched Input Monitoring permission detection to prefer
  `CGPreflightListenEventAccess()` before falling back to IOHID status.
- Added bounded refresh polling after Input Monitoring permission actions in
  the menu and Settings surfaces.
- Restored the stable macOS bundle identifier to `potapenko.VibeType` while
  keeping `CFBundleDisplayName` and `CFBundleName` as `VibeType`.
- Verification:
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
  - `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
  - `git diff --check`
  - built app metadata: `CFBundleIdentifier=potapenko.VibeType`,
    `CFBundleDisplayName=VibeType`, `CFBundleName=VibeType`
- Runtime QA: blocked. Computer Use showed both the previous user-run app and
  the newer `potapenko.VibeType` build during the session; after cleanup only
  the previous user-run app remained. Launching another
  menu bar instance would make the menu bar item ambiguous and risk interacting
  with the user's running app.
