# Batch 06 — Privacy

- Node type: leaf
- Status: complete
- Batch ID: `06-privacy`
- Change mode: Reconcile
- Source documents: 1
- Source words: 4744
- Read when: batch 06 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 06 is accepted.
- Maximum size: 100 physical lines.

## Source and baseline hash

- [Privacy and permissions](../../features/privacy-and-permissions.md) — `0fae9b68205372ff42e4ad73c044d12d014ae256637b7544a07083ef4bc7e04f`.

## Disposition

- Privacy and permissions: `contract` — hybrid with seven independently selectable leaves.

## Protected meaning

TCC/app-disclosure separation, setup ordering, passive Keychain prohibition,
permission state models, Accessibility/Input registration and recovery,
stable identity/signing, local retention exceptions, optional Dev Vlogs,
diagnostic redaction, legacy-released macOS, and iOS precedence remain unchanged.

## Acceptance

- Source retains its inbound path and one disposition.
- Nodes are reachable and at most 100 lines.
- Cumulative coverage reaches 16 of 54 pinned sources without duplicates/unknowns.
- No behavior, implementation, authority, precedence, or JSON state changes.

## Next

After push, activate batch `07-settings`.
