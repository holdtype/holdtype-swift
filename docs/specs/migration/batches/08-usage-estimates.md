# Batch 08 — Usage Estimates

- Node type: leaf
- Status: complete
- Batch ID: `08-usage-estimates`
- Change mode: Reconcile
- Source documents: 2
- Source words: 3489
- Read when: batch 08 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 08 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [macOS OpenAI usage estimate](../../features/openai-usage-estimate.md) — `fe7ced43bec99787326d72393939f98b4d924f2543fe8baa60a35475ecf96f8f`.
- [iOS transcription usage estimate](../../features/ios-usage-estimate.md) — `734ba352e1e666d167d20130f8b59ddf3831f396a49e4b9ee68ce86c85c14945`.

## Dispositions and protected meaning

- macOS estimate: `contract` — hybrid with events/pricing and Billing/storage leaves.
- iOS estimate: `contract` — hybrid with five responsibility leaves.
- Preserve macOS audio/text categories, provider tokens, Voice Prompt two-event
  behavior, V2/frozen rates; preserve iOS audio-only UUID handoff, one actor,
  strict 4-MiB wire format, retention, fencing, privacy, and release isolation.

## Acceptance and next

- Stable inbound paths, one disposition each, reachable nodes ≤100 lines.
- Coverage reaches 19/54 without duplicates/unknowns; hashes match.
- No behavior, implementation, authority, precedence, or JSON routing state changes.
- After push, activate batch `09-dev-vlogs`.
