---
id: VT-180
status: done
priority: P1
lane: permissions
dependencies:
  - VT-178
  - VT-179
allowed_paths:
  - VibeType.xcodeproj/project.pbxproj
  - docs/specs/features/privacy-and-permissions.md
  - backlog/vt-180-restore-accessibility-vibetype-bundle-id.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - plutil -p <built VibeType.app>/Contents/Info.plist
  - codesign -dvvv --entitlements :- <built VibeType.app>
  - git diff --check
---

# VT-180 - Restore Accessibility VibeType Bundle ID

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-178, VT-179
Expected outputs: current macOS app build uses the VibeType-cased TCC identity, spec supersedes the prior fallback
Verification: macOS build, built Info.plist/codesign inspection, git diff --check

## Goal

Restore the VT-178 Accessibility identity fix after VT-179 accidentally changed
the macOS bundle identifier back to the prior TCC identity.

## Scope

- Set the macOS app target Debug and Release bundle identifier to
  `potapenko.VibeType`.
- Keep `CFBundleDisplayName`, `CFBundleName`, and executable/product names as
  `VibeType`.
- Update the permissions spec so this behavior explicitly supersedes the prior
  bundle-id statement from VT-179.
- Verify the built app identity from Info.plist and codesign output.

## Non-goals

- Do not change iOS, test target, UserDefaults, Keychain, notification, or
  temporary-file identifiers.
- Do not reset TCC automatically.
- Do not install or invent a local Apple Development signing identity.
- Do not touch active recording-cache/settings work.

## Result

- Restored the macOS app target Debug and Release bundle identifier to
  `potapenko.VibeType` on top of the current HEAD after VT-179/recording-cache
  work restored the prior identity.
- Kept display name, bundle name, product name, and executable name as
  `VibeType`.
- Updated the permissions spec so the VibeType-cased bundle identifier is the
  current product contract for macOS Accessibility/Input Monitoring surfaces.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- Built app Info.plist confirmed `CFBundleDisplayName = VibeType`,
  `CFBundleExecutable = VibeType`, `CFBundleName = VibeType`, and
  `CFBundleIdentifier = potapenko.VibeType`.
- Built app codesign inspection confirmed `Identifier=potapenko.VibeType`,
  ad hoc local signing, `TeamIdentifier=not set`, and only
  `com.apple.security.get-task-allow`.
- Passed: `git diff --check`.
- Runtime note: the currently running app process must be quit and relaunched
  after this build before System Settings can use the restored bundle identity.
