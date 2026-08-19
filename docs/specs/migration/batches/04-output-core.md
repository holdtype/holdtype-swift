# Batch 04 — Output Core

- Node type: leaf
- Status: complete
- Batch ID: `04-output-core`
- Change mode: Reconcile
- Source documents: 3
- Source words: 5186
- Read when: batch 04 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 04 is accepted.
- Maximum size: 100 physical lines.

## Sources and baseline hashes

- [Text output](../../features/text-output-workflow.md) — `a907d29971692cd36987384736299d172b68805e6a897e2dc2682dcca75e5419`.
- [Post-transcription actions](../../features/post-transcription-actions.md) — `f625bd8957e5c9022ed273e01776c543c8f6f808687ab44a9680c1f478074402`.
- [Text correction](../../features/text-correction.md) — `25f0d41382f3d298666b4015f9ba89a84da526f1c6aa08632ad44171058d01e4`.

## Dispositions

- Text output: `contract` — hybrid with accepted/Last Result and insertion/failure leaves.
- Post-transcription actions: `contract` — hybrid with settings, runtime request, and strict result/failure leaves.
- Text correction: `contract` — hybrid with local pipeline, iOS Library, runtime failure, and storage/verification leaves.

## Protected meaning

- Final-stage order, app-owned Last Result, no-system-clipboard boundary,
  bulk insertion, Accessibility failure, strict translation, fail-open
  correction, iOS atomic replacement editing, persistence, cancellation,
  timeout, usage handoff, and fake-only testing remain unchanged.

## Acceptance

- Sources retain inbound paths and one disposition each.
- Nodes are reachable and at most 100 lines.
- Cumulative coverage reaches 12 of 54 pinned sources without duplicates/unknowns.
- No behavior, code, authority, precedence, or JSON state changes.

## Next

After push, activate batch `05-text-enhancement`.
