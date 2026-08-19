# Batch 18 — iOS Keyboard

- Node type: leaf
- Status: complete
- Batch ID: `18-ios-keyboard`
- Change mode: Reconcile
- Source documents: 2
- Source words: 7181
- Read when: batch 18 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 18 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Keyboard handoff](../../features/ios-keyboard-handoff-and-delivery.md) — `cb63be73343b81017e87cf99b900c4b59fdc51ad02bfb585ffb88ce4ead21538`.
- [Keyboard experience](../../features/ios-keyboard-experience.md) — `87e51a1408a1f05567e69345f5121e8196e8bd30ce06759fab580ff285a6c6f2`.

## Dispositions and protected meaning

- Both: `contract`, Active; handoff is canonical and wins listed conflicts.
- Preserve cold microphone flow, Voice isolation, retained audio, warm session,
  immutable destination/claim semantics, app-only fallback, Brand Stage, local
  utilities, privacy, and physical-device gates.

## Acceptance and next

- Stable hybrids and ten children; all reachable and ≤100 lines.
- Coverage reaches 38/54 without duplicates/unknowns; hashes match.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `19-ios-settings`.
