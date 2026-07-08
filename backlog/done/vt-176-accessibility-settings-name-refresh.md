---
id: VT-176
status: done
priority: P1
lane: permissions
dependencies:
  - VT-173
  - VT-174
allowed_paths:
  - VibeType.xcodeproj/project.pbxproj
  - VibeType/Services/PermissionsService.swift
  - VibeType/Settings/SetupPermissionsViewModel.swift
  - VibeTypeTests/PermissionsServiceTests.swift
  - VibeTypeTests/SetupPermissionsViewModelTests.swift
  - docs/specs/features/privacy-and-permissions.md
  - backlog/vt-176-accessibility-settings-name-refresh.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test -only-testing:VibeTypeTests/PermissionsServiceTests -only-testing:VibeTypeTests/SetupPermissionsViewModelTests
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-176 - Accessibility Settings Name And Refresh

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-173, VT-174
Expected outputs: explicit macOS display name, bounded Accessibility refresh, clearer setup instruction
Verification: focused permission tests, macOS build, git diff --check

## Goal

Make the Accessibility setup flow stop looking stale after the user enables
VibeType in System Settings, and make future System Settings display names
explicitly use `VibeType`.

## Scope

- Add an explicit macOS app display name for Debug and Release.
- Keep bundle identifiers stable unless a follow-up explicitly changes the
  product identity.
- Poll Accessibility trust for a bounded period after the request action so the
  Required Permissions window can update while System Settings is still open.
- Update the missing Accessibility instruction to tell the user to return to
  VibeType or quit and reopen if macOS still reports stale permission state.
- Add fake-backed tests for the refresh behavior and copy.

## Non-goals

- Do not reset TCC automatically.
- Do not remove System Settings rows automatically.
- Do not install or invent a local Apple Development signing identity.
- Do not touch active translation settings work from VT-175.

## Result

- Debug and Release now declare `CFBundleDisplayName = VibeType`; the app keeps
  the stable bundle identifier `potapenko.VibeType`.
- The Accessibility action starts a bounded status refresh loop after opening
  System Settings, so the setup surface can update when macOS starts reporting
  trust.
- The missing Accessibility instruction now tells the user to return to
  VibeType after enabling the toggle, and to quit and reopen if macOS still
  reports stale state.
- Existing System Settings rows remain an operator-visible TCC/Launch
  Services artifact; the app does not reset or delete those rows automatically.

## Verification

- `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test -only-testing:VibeTypeTests/PermissionsServiceTests -only-testing:VibeTypeTests/SetupPermissionsViewModelTests`
- `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- `plutil -p .../VibeType.app/Contents/Info.plist`: `CFBundleDisplayName`,
  `CFBundleExecutable`, and `CFBundleName` are `VibeType`.
- `codesign -d --entitlements :- .../VibeType.app`: only
  `com.apple.security.get-task-allow`; no sandbox entitlement.
- `git diff --check`
