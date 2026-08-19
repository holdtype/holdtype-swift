# Batch 02 — Recording Durability and History

- Node type: leaf
- Status: complete
- Batch ID: `02-recording-history`
- Change mode: Reconcile
- Source documents: 2
- Source words: 5037
- Read when: batch 02 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 02 is accepted.
- Maximum size: 100 physical lines.

## Sources and baseline hashes

- [Recording durability](../../features/recording-durability-and-interruption.md) — `c3a6e3bb67da0df16896cc252d12a3ec3d759e8e3bf9a9692985e2cafb2a79ef`.
- [Transcript History](../../features/transcript-history.md) — `ec8b5156f9cfe1a75551e275c6883fa09dd64093543e5bde4bbaa0e581e371e2`.

## Dispositions

- Recording durability: `contract` — retained as a cross-platform hybrid with
  terminal/capture, iOS/vlog, and saved-recording/feedback leaves.
- Transcript History: `contract` — retained as a macOS hybrid with seven
  independently selectable policy, state, action, data, and repair leaves.

## Protected meaning

- Terminal causes, explicit destructive authority, durable ownership,
  exact-once finalization, iOS cancellation, Dev Vlogs separation, playable
  validation, Voice Prompt, feedback, and log boundaries remain unchanged.
- Default-on max-20 accepted History, saved maximum-duration rows, dispatch
  seals, uncertain outcomes, Retry, raw-text recovery, row states, deletion,
  local fields, privacy, repair, and relaunch reconstruction remain unchanged.

## Acceptance

- Both sources retain inbound paths and one visible disposition.
- All created nodes are reachable and at most 100 physical lines.
- Cumulative coverage reaches 8 of 54 pinned sources with no duplicates or unknowns.
- No product code, behavior, authority, precedence, or JSON routing state changes.

## Next

After the scoped checkpoint is pushed, activate batch `03-transcription`.
