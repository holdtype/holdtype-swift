---
id: VT-173
status: done
priority: P1
lane: permissions
dependencies:
  - VT-170
allowed_paths:
  - docs/specs/features/privacy-and-permissions.md
  - VibeType.xcodeproj/project.pbxproj
  - backlog/vt-173-accessibility-unsandboxed-macos-target.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - codesign -d --entitlements :- <built VibeType.app>
  - git diff --check
---

# VT-173 - Accessibility Unsandboxed macOS Target

Status: done
Priority: P1
Lane: permissions
Dependencies: VT-170
Expected outputs: macOS app target sandbox setting repair, permission spec update
Verification: xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build; codesign entitlement inspection; git diff --check

## Goal

Fix the recurring Accessibility setup failure where the request action opens
System Settings but VibeType is not present in the Accessibility application
list.

## Scope

- Keep the existing request-first Accessibility action from VT-170.
- Disable App Sandbox for the macOS VibeType app target because MVP text
  insertion controls the active app through Accessibility-gated event posting.
- Update the permission spec so future build-configuration work does not
  re-enable sandboxing for the macOS MVP without a replacement architecture.
- Verify that the built app no longer carries the App Sandbox entitlement.

## Non-goals

- Change iOS targets.
- Add a privileged helper.
- Reset or edit the user's TCC permission database.
- Change microphone or OpenAI setup behavior.

## Acceptance

- The macOS app target builds with App Sandbox disabled.
- The built VibeType app entitlements no longer include
  `com.apple.security.app-sandbox`.
- The privacy/permissions spec records the Accessibility sandbox constraint.
- Existing dirty work from other active tasks remains unstaged and untouched.

## Result

- Disabled App Sandbox for the macOS VibeType app target in Debug and Release.
- Removed the generated user-selected file sandbox entitlement from the macOS
  app target settings.
- Updated the privacy/permissions spec to keep the macOS MVP unsandboxed while
  Accessibility-gated active-app control is part of the product contract.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- Passed: `codesign -d --entitlements :- /Users/eugenepotapenko/Library/Developer/Xcode/DerivedData/VibeType-ftedevspxcuzjabsxletvjdurczh/Build/Products/Debug/VibeType.app`
- Passed: `git diff --check`
- Entitlement result: only `com.apple.security.get-task-allow`; no
  `com.apple.security.app-sandbox`.
- Tooling: XcodeBuildMCP checked; no macOS build/test tool exposed in this
  session, so verification used the repository xcodebuild fallback.
  Runtime QA: manual permission grant remains user-controlled.
