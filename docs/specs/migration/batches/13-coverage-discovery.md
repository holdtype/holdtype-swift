# Batch 13 — Coverage And Discovery

- Node type: leaf
- Status: complete
- Batch ID: `13-coverage-discovery`
- Change mode: Reconcile
- Source documents: 3
- Source words: 1255
- Read when: batch 13 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 13 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Historical spec backlog](../../backlog.md) — `5589de60f4bb824f4ed60b5289bf9dd11f018319719e52b59be1f6e36cd2b8b1`.
- [Brownfield discovery](../../brownfield-discovery.md) — `b20b302b51315475ce5dc1c7ca9f482b4809aea270c2ff5df630df1ec89f9940`.
- [UI/functionality coverage](../../features/ui-functionality-coverage.md) — `9b7504999381fbf3c2f353d6108033ca7cbe3c0c663c8dc355906f2510778a37`.

## Dispositions and protected meaning

- Backlog: `historical`; brownfield and coverage maps: `resource`.
- Preserve non-authority status, current-checkout caveat, contract-first routing,
  source/test hints, verification routes, compact selector, and retired-reference boundary.

## Acceptance and next

- Stable paths; one disposition each; nodes reachable and ≤100 lines.
- Coverage reaches 30/54 without duplicates/unknowns; hashes match.
- No product/source/backlog body, behavior, or JSON routing state changes.
- After push, activate batch `14-backlog-automation`.
