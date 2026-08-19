# macOS And Runtime Evidence

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.platform-testing@1`
- Clauses: `QA.UNIT`, `QA.MACOS`, `QA.COMPUTER-USE`
- Read when: macOS model/build/runtime/UI verification is being selected.
- Do not read when: the selected task is iOS-only.
- Maximum size: 100 physical lines.

- Unit/model tests cover deterministic state, settings mapping, errors,
  fake-clock timeouts, output decisions, and request construction.
- Normal Swift behavior uses macOS build/test plus diff hygiene. Prefer available
  macOS-capable build tooling; otherwise documented `xcodebuild` fallback.
- Changed menu, Settings, indicator, permission UI, paste handoff, controls,
  labels/status, or visible end-to-end seam requires bounded runtime smoke.
- Computer Use is required for changed visible macOS surfaces, demonstrating
  existence and interaction, never replacing service assertions.
- Every implementation reports runtime QA: `required` (used), `not_applicable`
  (model/service only with deterministic evidence), or `blocked` (bounded run
  could not reach surface, with exact blocker and last build/test evidence).
- A quick launch/inspection blocker stays explicit rather than expanding into
  an unbounded manual session.
