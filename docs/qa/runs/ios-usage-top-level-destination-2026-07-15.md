# iOS Usage Top-Level Destination QA

Date: 2026-07-15

## Scope

- Move the existing Transcription Usage Estimate from Settings into a fifth
  containing-app destination.
- Keep the top-level order `Voice`, `Rules`, `History`, `Usage`, `Settings`.
- Preserve the existing local usage summary, chart, refresh, warning, and Reset
  behavior without changing Domain, Persistence, or composition ownership.

## Automated Evidence

- Focused iOS Simulator run on iPhone 16 / iOS 18.6:
  `IOSContainingAppShellTests` and `IOSUsageEstimateStateOwnerTests` passed with
  21 tests in 2 suites.
- Full `HoldType-iOS` iPhone 16 / iOS 18.6 Simulator regression passed with
  1,135 tests in 145 suites.
- The macOS `HoldType` build passed.
- `git diff --check` passed.

No automated command contacted OpenAI, loaded a live Keychain item, requested
microphone permission, or changed external billing data.

## Runtime Evidence

- The app was installed and launched with `HOLDTYPE_AUTOMATION=1` and
  `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip` on iPhone 16 / iOS 18.6.
- The iPhone tab bar showed five destinations in the required order: Voice,
  Rules, History, Usage, and Settings.
- Usage opened directly from the tab bar and exposed
  `ios.destination.usage`, the `Transcription Usage Estimate` title, local
  empty state, Refresh, and disabled Reset for an empty summary.
- Settings contained OpenAI, Language & Writing, Voice, Privacy, and
  Development. It contained no Usage section or Usage navigation row.
- The Usage surface and five-tab inventory remained present at the Simulator's
  pre-existing maximum accessibility content size. Standard-size inspection
  confirmed the complete Settings inventory.

## Cleanup

- The Simulator content size was restored to
  `accessibility-extra-extra-extra-large`.
- The run-owned app process was terminated.
- The scoped `caffeinate` process was stopped.
