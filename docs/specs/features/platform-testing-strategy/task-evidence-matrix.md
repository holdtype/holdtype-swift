# Task Evidence Matrix

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.platform-testing@1`
- Clause: `QA.TASK-MATRIX`
- Read when: determining the minimum verification for a bounded change.
- Do not read when: verification is already pinned by a narrower acceptance contract.
- Maximum size: 100 physical lines.

- Docs/spec-only: `git diff --check`.
- Swift model/service: matching macOS test plus diff check.
- App shell/UI/visible interaction: macOS build plus diff check and bounded
  Computer Use smoke or concrete blocker.
- External service: fake-backed tests with bounded timeout; no live provider.
- Permission/microphone: fake state logic; runtime only when platform evidence is requested.
- iOS behavior: matching simulator build/test/screenshot; retain typecheck and
  blocker if full build/run times out.
- Shared visible surface: both SDKs plus bounded iOS runtime when buildable.
- Select evidence only for the touched platform/domain. macOS-only work does
  not inherit iOS checks; iOS-specific work does.
