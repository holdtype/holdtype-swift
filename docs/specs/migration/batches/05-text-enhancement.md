# Batch 05 — Text Enhancement

- Node type: leaf
- Status: complete
- Batch ID: `05-text-enhancement`
- Change mode: Reconcile
- Source documents: 3
- Source words: 5902
- Read when: batch 05 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 05 is accepted.
- Maximum size: 100 physical lines.

## Sources and baseline hashes

- [Text Fixes](../../features/text-fixes.md) — `e78f990d8ccc0fe30b2f4bc7a6ceeaafaa5d4aa70257431c493af677ea8b6a9b`.
- [Built-in writing skill](../../features/text-fixes-writing-skill.md) — `81d23a70ed89304cbfbae7a456c3d3c2b1fe8193d84689d3a1808f438ea239bc`.
- [Voice emoji commands](../../features/voice-emoji-commands.md) — `4e1a212947e63539938c05e70b96c9045f03d1038fa6b2f0a395568df22a4c70`.

## Dispositions

- Text Fixes: `contract` — hybrid with six independently selectable leaves.
- Built-in writing skill: `contract` — bounded macOS addendum retaining narrow precedence.
- Voice emoji commands: `contract` — hybrid with catalog/settings and matching/output leaves.

## Protected meaning

Catalog IDs and migrations, exact targets and output, stale/once-only
replacement, timeout/cancellation, Voice Prompt's two stages, consent v4,
keyboard fail-closed, app-private iOS storage, local emoji matching, custom
precedence, accepted status, legacy-released macOS, and current iOS precedence remain unchanged.

## Acceptance

- Sources retain inbound paths and one disposition each.
- Nodes are reachable and at most 100 lines.
- Cumulative coverage reaches 15 of 54 pinned sources without duplicates/unknowns.
- No behavior, implementation, authority, precedence, or JSON state changes.

## Next

After push, activate batch `06-privacy`.
