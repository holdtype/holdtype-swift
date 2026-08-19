# Batch 07 — Settings

- Node type: leaf
- Status: complete
- Batch ID: `07-settings`
- Change mode: Reconcile
- Source documents: 1
- Source words: 5376
- Read when: batch 07 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 07 is accepted.
- Maximum size: 100 physical lines.

## Source and baseline hash

- [Settings and secret storage](../../features/settings-and-secret-storage.md) — `9bb0f524f4afa0b4d35949b8459eb8f675acf4ff4de4e7123b0406d056ebf04b`.

## Disposition

- Settings and secret storage: `contract` — hybrid with eight responsibility leaves.

## Reconciliation

One stale `Restore Defaults` mention was not carried forward because the
narrower Active `text-fixes@3` explicitly forbids that action and governs the
Fixes editor. No other semantic discrepancy exists.

## Protected meaning

macOS legacy-released UserDefaults/Keychain/Login Item/Finder/Sparkle ownership,
runtime credential cache, defaults, audio/cache/history controls, local-only
support surfaces, Dev Vlogs separation, and iOS precedence remain unchanged.

## Acceptance and next

- Source retains its inbound path and one disposition; nodes remain reachable
  and at most 100 lines; coverage reaches 17/54 without duplicates/unknowns.
- No implementation, authority, precedence, unrelated behavior, or JSON state changes.
- After push, activate batch `08-usage-estimates`.
