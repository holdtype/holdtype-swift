# App Store Distribution Decision

- Node type: hybrid
- Contract ID: `holdtype.macos.distribution-channel`
- Domain ID: `holdtype.macos.distribution`
- Status: Active
- Stability: Accepted
- Release baseline: direct-download macOS product
- Contract revision: `holdtype.macos.distribution-channel@1`
- Read when: macOS channel, sandbox viability, official download trust, or Store reconsideration is in scope.
- Do not read when: iOS/TestFlight distribution is in scope.
- Maximum size: 100 physical lines.

## Decision

Current macOS HoldType ships directly, not through Mac App Store: Developer ID
signed/notarized artifact, Sparkle for downloads, optional Homebrew cask using
the same artifact, and public download/privacy/support/changelog pages.

The Store sandbox conflicts with Accessibility-gated automatic insertion,
Paste Last Result, and Nearby Text across arbitrary active apps. Microphone and
networking are not the main blockers.

## Children

- [User trust and channel rules](app-store-distribution/user-trust-and-channel-rules.md) — official source, copy, forbidden Store work, and future fork.
- [Release qualification](app-store-distribution/release-qualification.md) — signing/notarization/Gatekeeper/DMG/appcast and final audio-input entitlement proof.

## Invariants

- Do not create Store build, entitlements, CI, TestFlight, metadata, or assets
  while this decision stands.
- Do not weaken active-app features solely for Store compatibility without a
  separate product decision/spec. Any future Store edition cannot use Sparkle.
- Production bundle identity remains direct-download identity.
