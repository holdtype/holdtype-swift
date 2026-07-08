---
id: VT-174
status: done
priority: P1
lane: permissions
dependencies:
  - VT-031
  - VT-149
allowed_paths:
  - VibeType.xcodeproj/**
  - VibeType/**
  - VibeTypeTests/**
  - docs/specs/features/privacy-and-permissions.md
  - docs/qa/macos/**
  - backlog/vt-174-microphone-permission-persistence.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-174 - Microphone Permission Persistence

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-031, VT-149
Expected outputs: signing persistence support, setup permission UI clarity, verification result
Verification: xcodebuild build, git diff --check

## Goal

Stop the macOS development app from looking like a new microphone permission
client after rebuilds, and make the Required Permissions UI clear when
microphone access is already allowed but another required setup item still
needs attention.

## Scope

- Add repo-safe support for local stable code-signing configuration without
  committing a personal Apple development team.
- Keep microphone permission state sourced from macOS TCC through AVFoundation.
- Avoid showing completed microphone access as an action item in the compact
  Required Permissions flow.
- Update product/spec notes if the user-visible permission behavior changes.

## Non-goals

- Do not store microphone permission in UserDefaults or another app-owned
  persistence layer.
- Do not create or install an Apple developer certificate.
- Do not reset TCC or require the operator to run destructive privacy reset
  commands.
- Do not change recording, transcription, paste, or OpenAI behavior.

## Result

- Added `Config/VibeTypeSigning.xcconfig` as the macOS app target signing base
  configuration.
- Added `Config/VibeTypeSigning.local.xcconfig.example` and ignored the real
  local override so a developer can set `VIBETYPE_DEVELOPMENT_TEAM` and
  `VIBETYPE_CODE_SIGN_IDENTITY` without committing personal signing data.
- Kept the default fallback as `Sign to Run Locally` so command-line builds
  continue to pass when no Apple Development certificate exists.
- Updated the compact Required Permissions view so completed microphone access
  is not shown as an actionable remaining setup item.
- Added focused unit coverage for compact permission-row visibility.
- Updated the privacy/permissions spec to require the compact setup surface to
  focus on remaining actionable permission items.
- Recorded QA evidence in
  `docs/qa/macos/vt-174-2026-07-06-microphone-permission-persistence.md`.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test -only-testing:VibeTypeTests/PermissionsSettingsSectionVisibilityTests`
- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- Passed: `git diff --check`
- Build settings confirmed fallback values:
  `VIBETYPE_CODE_SIGN_IDENTITY = -`,
  `VIBETYPE_CODE_SIGN_STYLE = Automatic`, and
  `PRODUCT_BUNDLE_IDENTIFIER = potapenko.VibeType`.
- Info.plist confirmed `NSMicrophoneUsageDescription`.

## Blocker Evidence

- `security find-identity -p codesigning -v` reports `0 valid identities found`
  on this Mac.
- Fresh build signing inspection still reports `Signature=adhoc` and
  `TeamIdentifier=not set`.
- Without a stable Apple Development signing identity, macOS can continue to
  treat rebuilt ad hoc app bundles as new TCC clients, so real microphone
  permission persistence cannot be proven on this machine.

## Resolution Path

- Install or select an Apple Development code-signing identity in Xcode or
  Keychain.
- Fill the ignored `Config/VibeTypeSigning.local.xcconfig` from the checked-in
  example with the local Apple development team id.
- Rebuild and confirm `codesign -dvvv --entitlements :- <VibeType.app>` shows a
  non-ad-hoc signature with a `TeamIdentifier`.
- Launch through LaunchServices with `open -n <VibeType.app>`, grant microphone
  access once, rebuild, relaunch, and confirm the microphone prompt does not
  repeat.

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Closed with user-provided live evidence: on 2026-07-07 the user dictated
  this chat text through the current VibeType app, confirming microphone
  permission and recording are working in the installed app. Repo-side signing
  config and permission UI support are already present.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
