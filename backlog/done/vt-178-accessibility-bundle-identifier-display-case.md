---
id: VT-178
status: done
priority: P1
lane: permissions
dependencies:
  - VT-176
allowed_paths:
  - VibeType.xcodeproj/project.pbxproj
  - docs/specs/features/privacy-and-permissions.md
  - backlog/vt-178-accessibility-bundle-identifier-display-case.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - plutil -p <built VibeType.app>/Contents/Info.plist
  - codesign -dvvv --entitlements :- <built VibeType.app>
  - git diff --check
---

# VT-178 - Accessibility Bundle Identifier Display Case

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-176
Expected outputs: macOS Accessibility row uses `VibeType` fallback name, built bundle identity evidence
Verification: macOS build, built Info.plist/codesign inspection, git diff --check

## Goal

Stop macOS Accessibility settings from recreating the VibeType row as
`vibetype` when the user removes the old row and invokes the app's Accessibility
permission action again.

## Scope

- Change the macOS app target bundle identifier to a VibeType-cased identifier
  if System Settings uses the bundle identifier as the row-name fallback.
- Preserve `CFBundleDisplayName`, `CFBundleName`, `CFBundleExecutable`, product
  name, target name, and visible copy as `VibeType`.
- Record the observed platform behavior in the permissions spec.
- Verify the built app identity and signing state.

## Non-goals

- Do not change UserDefaults, Keychain, notification, temporary-file, or test
  suite keys that intentionally remain lowercase machine identifiers.
- Do not reset TCC automatically.
- Do not install or invent a local Apple Development signing identity.
- Do not touch active translation settings work from VT-177.

## Result

- Changed the macOS app target Debug and Release bundle identifier to
  `potapenko.VibeType`.
- Kept visible app name fields and product/executable identity as `VibeType`.
- Preserved non-user-facing lowercase identifiers such as settings, temporary
  file, and test keys.
- Recorded that Accessibility settings must resolve the user-facing app row to
  `VibeType` even when macOS falls back to bundle identifier metadata.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- Built app Info.plist confirmed `CFBundleDisplayName = VibeType`,
  `CFBundleExecutable = VibeType`, `CFBundleName = VibeType`, and
  `CFBundleIdentifier = potapenko.VibeType`.
- Built app codesign inspection confirmed `Identifier=potapenko.VibeType`,
  ad hoc local signing, `TeamIdentifier=not set`, and only
  `com.apple.security.get-task-allow`.
- Fresh DerivedData build also confirmed `CFBundleIdentifier =
  potapenko.VibeType` and `Identifier=potapenko.VibeType`.
- Passed: `git diff --check`
