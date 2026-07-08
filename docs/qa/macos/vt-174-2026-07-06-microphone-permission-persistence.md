# macOS QA Run Report

Date: 2026-07-06 13:40 CEST
Task: VT-174 - Microphone Permission Persistence
Tooling: `xcodebuild`, `codesign`, `plutil`, `security`
MCP tools checked: yes; no macOS build/run/UI operation surface was exposed in
this session. XcodeBuildMCP exposed simulator-oriented tools, and Computer Use
exposed only coordinate clicking.
Runtime QA: blocked

## Scenario

Verify that the app has a repo-safe path to stable local code signing for macOS
TCC permission persistence, and that the compact Required Permissions surface no
longer presents an already allowed microphone permission as an action item.

## Actions

1. Added a tracked signing `.xcconfig` with an ad hoc fallback and optional
   untracked local override support.
2. Confirmed build settings resolve the fallback values:
   `HOLDTYPE_CODE_SIGN_IDENTITY = -`, `HOLDTYPE_CODE_SIGN_STYLE = Automatic`,
   and `PRODUCT_BUNDLE_IDENTIFIER = app.holdtype.HoldType`.
3. Added unit coverage for compact permissions visibility.
4. Ran focused unit tests, macOS build, diff hygiene, and signing inspection.
5. Checked local signing identities with `security find-identity -p codesigning -v`.

## Expected

- With a local Apple Development identity configured, debug builds should have
  a stable signing identity so macOS can recognize HoldType across rebuilds for
  microphone permission decisions.
- Without a local identity, builds should continue to work with the explicit
  ad hoc fallback.
- The compact setup surface should focus on remaining actionable permission
  items and not make an allowed microphone permission look unresolved.

## Observed

- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination 'platform=macOS' test -only-testing:HoldTypeTests/PermissionsSettingsSectionVisibilityTests`
  passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination 'platform=macOS' build`
  passed.
- `git diff --check` passed.
- `codesign -dvvv --entitlements :- .../HoldType.app` still reports
  `Signature=adhoc` and `TeamIdentifier=not set` on this machine because no
  valid code-signing identities are installed.
- `security find-identity -p codesigning -v` reports `0 valid identities found`.
- Info.plist contains `CFBundleIdentifier = app.holdtype.HoldType` and
  `NSMicrophoneUsageDescription`.

## Result

BLOCKED for proving real TCC persistence on this Mac until an Apple Development
signing identity is installed and selected through the ignored local signing
override. Repository support and unit-covered setup UI behavior are complete.

## Resolution Path

1. Install or select an Apple Development code-signing identity in Xcode or
   Keychain.
2. Create the ignored `Config/HoldTypeSigning.local.xcconfig` from the checked-in
   example and set the local team id.
3. Rebuild and confirm `codesign` shows a non-ad-hoc signature with a
   `TeamIdentifier`.
4. Launch the app through LaunchServices with `open -n <HoldType.app>`, grant
   microphone access once, rebuild, relaunch, and confirm macOS does not prompt
   for microphone access again.
