# Batch 17 — iOS Voice

- Node type: leaf
- Status: complete
- Batch ID: `17-ios-voice`
- Change mode: Reconcile
- Source documents: 2
- Source words: 5168
- Read when: batch 17 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 17 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Voice state](../../features/ios-v1-voice-state-persistence.md) — `35baf101bac25170d481cf9e851abf3ab9f76c5cc70f613f4ccfb1bd9836594d`.
- [Voice Draft](../../features/ios-voice-draft.md) — `ead0f64ecde1313f42acc2c5342481814ca30dfc0da22e442991c16a2684f109`.

## Dispositions and protected meaning

- Both sources: `contract`, Active/Accepted current V1.1 authority.
- Preserve persistence replacement precedence, remote replay blocks, exact
  local cleanup, protected audio, composed Draft independence, CAS/exact-once
  editing, process-only Undo, fixed Voice geometry, and recovery routing.

## Acceptance and next

- Stable hybrids and eight children; all reachable and ≤100 lines.
- Coverage reaches 36/54 without duplicates/unknowns; hashes match.
- No implementation, behavior, QA artifact, or JSON routing-state change.
- After push, activate batch `18-ios-keyboard`.
