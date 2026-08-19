# iOS And Keyboard Evidence

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.platform-testing@1`
- Clauses: `QA.IOS`, `QA.KEYBOARD`
- Read when: an iOS target, cross-platform SwiftUI surface, or keyboard extension is changed.
- Do not read when: ordinary macOS-only work is in scope.
- Maximum size: 100 physical lines.

- Explicit iOS work uses Build iOS Apps/Xcode tooling or documented fallback
  for simulator build/test/screenshot/interaction. A timeout without compiler
  diagnostics records a blocker while preserving SDK typecheck evidence.
- Hosted tests use `Debug-Tests`; test-host may temporarily contain xctest.
  Ordinary Debug/Release products must contain no xctest, test dSYM, or XCTest
  support after tests, and next launch must not install a test-sized app.
- Shared SwiftUI changes typecheck/build both SDKs and, when bounded, run/
  capture iOS simulator evidence.
- Keyboard is a separate architecture: containing app owns onboarding/settings/
  permissions/recording/network; extension owns compact UI/insertion. It must
  switch keyboards and remains unavailable in secure/phone-pad contexts.
- Brand Stage simulator proof includes embedded `.appex`, processed
  `com.apple.keyboard-service`, actual approved controls, and Light/Dark status.
- Restricted App Group, secure fallback, keyboard switching, host rejection,
  process eviction, and iPad floating layout remain physical-device evidence.
- Current product contracts, not this strategy, decide Full Access and handoff behavior.
