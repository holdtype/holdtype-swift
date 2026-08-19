# Product Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting a HoldType product contract by platform or responsibility.
- Do not read when: only authority status or migration progress is needed.
- Maximum size: 100 physical lines.

This branch grows one bounded migration batch at a time. Until a domain branch
is migrated, select its legacy source through the
[authority index](../index.md).

## Children

- [macOS contracts](macos/README.md) — shipped macOS application-shell and
  platform-specific behavior.
- [Shared contracts](shared/README.md) — cross-platform ownership and behavior
  that platform-specific contracts must preserve.
- [iOS contracts](ios/README.md) — current iOS product behavior migrated one
  bounded domain at a time.
- [QA contracts](qa/README.md) — platform evidence selection and deterministic
  verification boundaries.
- [Distribution contracts](distribution/README.md) — macOS direct channel,
  native updates, artifacts, trust, and release qualification.
- [Website contracts](website/README.md) — landing hosting, Pages/feed
  coexistence, localization, media, and publication integrity.

## Pending branches

Other shared capabilities, pending iOS domains, distribution and website, and operations remain in
the legacy authority index until their approved batches establish those branch
nodes. Pending text is not product authority and does not change precedence.

## Dependencies

- [Authority index](../index.md) — current status, precedence, and legacy
  routing during migration.
