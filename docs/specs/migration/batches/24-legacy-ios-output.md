# Batch 24 — Legacy iOS Output

- Node type: leaf
- Status: complete
- Batch ID: `24-legacy-ios-output`
- Change mode: Reconcile
- Source documents: 2
- Source words: 10547
- Read when: batch 24 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 24 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Output actions](../../features/ios-output-actions.md) — `5a57c75b4c49ea299aa3ad474c413b6798588d3d4f4353aeb8a07a0cdd366fe5`.
- [Accepted delivery](../../features/ios-accepted-output-delivery-record.md) — `3159e8ba139f61c47d031770cb3fb4b818e32349afdf616734e83a8b0e6ac373`.

## Dispositions and protected meaning

- Both: `historical`; current release/Voice state/handoff precedence preserved.
- Retain legacy accepted-output identity, exact bytes, at-most-once insertion,
  honest acknowledgement, durability/CAS, History/outbox ordering, recovery,
  expiry, privacy, compatibility, and fail-closed evidence without activation.

## Acceptance and next

- Two historical hybrids and nine children; reachable and ≤100 lines.
- Coverage reaches 49/54 without duplicates/unknowns; hashes match.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `25-legacy-ios-history`.
