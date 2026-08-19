# Batch 19 — iOS Settings

- Node type: leaf
- Status: complete
- Batch ID: `19-ios-settings`
- Change mode: Reconcile
- Source documents: 2
- Source words: 9020
- Read when: batch 19 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 19 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Settings and secrets](../../features/ios-settings-and-secret-storage.md) — `52c9ba421ba75af19740a5dff3e4191b820b52906bbcadb65d20a201a78c89df`.
- [Guided recovery](../../features/ios-settings-guided-recovery.md) — `2fc644755c2a01d05a2a44bf07b19d0b78baa8269cfe21a7f76d1da66c7cb46d`.

## Dispositions and protected meaning

- Both: `contract`, current/approved within V1.1 precedence.
- Preserve Keychain/marker transaction safety, no passive reads, protected JSON,
  process owners, autosave and explicit-editor semantics, private catalogs,
  truthful setup, and exact field-level recovery.

## Acceptance and next

- Stable settings hybrid with 11 children plus guided leaf; all reachable ≤100 lines.
- Coverage reaches 40/54 without duplicates/unknowns; hashes match.
- No implementation, behavior, credential, automation, or JSON routing-state change.
- After push, activate batch `20-ios-voice-audio`.
