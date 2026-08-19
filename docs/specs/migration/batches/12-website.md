# Batch 12 — Website

- Node type: leaf
- Status: complete
- Batch ID: `12-website`
- Change mode: Reconcile
- Source documents: 2
- Source words: 2877
- Read when: batch 12 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 12 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Landing hosting](../../features/landing-page-hosting.md) — `3d198ff71a180da57f11147b38f2f1d9a10ad9053df2cf73e8a52a4f6f5e14e9`.
- [Landing localization](../../features/landing-page-localization.md) — `6bb363e6fb3a45e346d0bcfebc069c86fa1e5c3bc7861c88d90af67f1c94916c`.

## Dispositions and protected meaning

- Both: `contract`, retaining stable hybrid inbound paths.
- Preserve DigitalOcean/Pages separation, stable appcast, DNS safety, public
  claim limits, social/tutorial/modal behavior, ten routes, direct-route
  precedence, root detection, semantic locale parity, RTL, and atomic failures.

## Acceptance and next

- Nodes reachable and ≤100 lines; coverage reaches 27/54 without duplicates/unknowns.
- Hashes match; no public behavior, deployment, updater, or JSON state changes.
- After push, activate batch `13-coverage-discovery`.
