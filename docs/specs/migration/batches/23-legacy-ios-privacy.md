# Batch 23 — Legacy iOS Privacy

- Node type: leaf
- Status: complete
- Batch ID: `23-legacy-ios-privacy`
- Change mode: Reconcile
- Source documents: 2
- Source words: 5269
- Read when: batch 23 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 23 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Privacy](../../features/ios-privacy-and-permissions.md) — `512e130ee70ff361ad74f0bd165243511b85995f1e7217426fceb998a74e2b97`.
- [Consent record](../../features/ios-provider-consent-record.md) — `187417ee54ddbec192f8d60162c27ad0db589525d797848644de0d56792bb86d`.

## Dispositions and protected meaning

- Both: `historical`; current V1.1 disclosure/privacy precedence preserved.
- Retain permission separation, legacy disclosure/manifests, strict record/CAS/
  fence/root/provider-stage safety, durability, and non-activation boundaries.

## Acceptance and next

- Two historical hybrids and seven children; reachable and ≤100 lines.
- Coverage reaches 47/54 without duplicates/unknowns; hashes match.
- No implementation, behavior, privacy artifact, or JSON routing-state change.
- After push, activate batch `24-legacy-ios-output`.
