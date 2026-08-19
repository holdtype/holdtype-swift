# Batch 11 — Distribution

- Node type: leaf
- Status: complete
- Batch ID: `11-distribution`
- Change mode: Reconcile
- Source documents: 2
- Source words: 1965
- Read when: batch 11 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 11 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Software updates](../../features/software-updates.md) — `b088f937f41b51d42765aced538164c19625357e32b12ae01380eb4a65cdfae0`.
- [Distribution decision](../../features/app-store-distribution.md) — `30a745be511eef07227a9cf6e0b59eb306258dad36e927832cd9991335d6796a`.

## Dispositions and protected meaning

- Both: `contract`, retaining stable hybrid inbound paths.
- Preserve direct-not-Store decision, sandbox rationale, canonical DMG,
  Sparkle/GitHub/Homebrew, macOS 14+, updater relaunch durability, signing/
  notarization, and final audio-input entitlement gate.

## Acceptance and next

- Nodes reachable and ≤100 lines; coverage reaches 25/54 without duplicates/unknowns.
- Hashes match; no implementation, channel, behavior, or JSON state changes.
- After push, activate batch `12-website`.
