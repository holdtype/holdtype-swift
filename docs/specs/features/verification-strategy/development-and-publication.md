# Development And Publication Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.verification-strategy@1`
- Clause: `VERIFY.PUBLICATION`
- Read when: deciding whether tests/runtime QA gate a publication action.
- Do not read when: only a development service seam is in scope.
- Maximum size: 100 physical lines.

- Tests, fakes, focused smoke, and suites are development/release-preparation evidence.
- An explicit user publish instruction does not start, rerun, or wait for tests
  and does not turn their current state into a publication gate.
- Publication still verifies distributable inputs, signing, entitlements,
  notarization, checksums, DMG installation, appcast metadata, and download
  channels. These are artifact-integrity checks, not product test execution.
- A capability explicitly excluded from the release may keep incomplete tests/
  runtime QA without blocking that release; notes must make no excluded claim.
