# Direct Distribution Release Qualification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.distribution-channel@1`
- Clause: `DISTRIBUTION.VERIFY`
- Read when: qualifying the final direct-download macOS artifact.
- Do not read when: only website copy or iOS release is in scope.
- Maximum size: 100 physical lines.

- Validate Developer ID signing, notarization, stapling, Gatekeeper assessment,
  DMG layout, Sparkle appcast, and final artifact trust.
- Final exported app inside DMG/installed copy—not build settings/archive log—
  must contain Hardened Runtime `com.apple.security.device.audio-input` in
  `codesign -dvvv --entitlements :-` output. Missing entitlement blocks release.
- Known missing-entitlement symptom: Request Microphone Access immediately
  becomes Not Allowed, no native prompt, and no HoldType row in System Settings.
- Website/download QA confirms install/trust copy. Future Store work first runs
  a new sandbox feasibility spike and updates the channel contract.
