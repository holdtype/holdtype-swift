# Root Xcode Flatten QA

Date: 2026-06-21
Task: direct structural migration to move the Xcode project and source folders
to the repository root.

## Scope

- Move `holdtype.xcodeproj`, app source folders, shared source, and test
  folders from the nested `holdtype/` container to the repository root.
- Update backlog, docs, runbooks, and verification commands to use root-level
  Xcode paths.
- Remove tracked Xcode `xcuserdata` files from the repository; they remain
  ignored by `.gitignore`.

## Commands And Results

- `xcodebuild -list -project holdtype.xcodeproj`
  - Result: passed.
  - Targets listed: `holdtype`, `holdtype-iOS`, `holdtypeIOSTests`,
    `holdtypeTests`, `holdtypeUITests`.
  - Schemes listed: `holdtype`, `holdtype-iOS`.
- `git diff --check`
  - Result: passed.
- `python3 scripts/backlog_next.py --json`
  - Result: passed; selector returned `no_ready`.
- `xcrun swiftc -typecheck` for `Shared/` plus macOS `holdtype/` sources
  - Result: passed.
- `xcrun swiftc -typecheck` for `Shared/` plus `holdtypeIOS/` sources
  - Result: passed.
- `/opt/homebrew/bin/timeout 240 xcodebuild -project holdtype.xcodeproj -scheme holdtype -destination 'platform=macOS' build`
  - Result: timed out with `BUILD INTERRUPTED`; no compiler diagnostics were
    emitted before timeout.
- `/opt/homebrew/bin/timeout 240 xcodebuild -project holdtype.xcodeproj -scheme holdtype-iOS -destination 'generic/platform=iOS Simulator' build-for-testing`
  - Result: timed out with `BUILD INTERRUPTED`; no compiler diagnostics were
    emitted before timeout.

## Result

Runtime QA: not applicable for this structural migration.

The root-level Xcode project parses and the moved Swift source sets typecheck
against macOS and iOS SDKs. Full `xcodebuild` remains blocked by the same
bounded timeout pattern seen before the flattening.
