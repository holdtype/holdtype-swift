# Batch 20 — iOS Voice And Audio

- Node type: leaf
- Status: complete
- Batch ID: `20-ios-voice-audio`
- Change mode: Reconcile
- Source documents: 1
- Source words: 7989
- Read when: batch 20 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 20 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [Voice session and audio](../../features/ios-voice-session-and-audio.md) — `40f208b88c709b555a7ed1f621d4110f022c2d795188c52d03d422c34d95d613`.

## Disposition and protected meaning

- Source: `contract`, Active foreground reference; Quick Session section Historical.
- Preserve V1.1 precedence, ordered preflight, descriptor audio, unknown-duration
  preservation, one process owner, route/interruption policy, no P4 background
  mode, provider replay safety, runtime types, and physical gates.

## Acceptance and next

- Stable hybrid with ten responsibility children; all reachable and ≤100 lines.
- Coverage reaches 41/54 without duplicates/unknowns; source hash matches.
- No implementation, behavior, entitlement, QA artifact, or JSON routing-state change.
- After push, activate batch `21-ios-diagnostics`.
