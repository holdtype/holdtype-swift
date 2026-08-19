# History Window, Copy, Playback, and Deletion

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.window`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.window@1`
- Read when: History presentation, ordering, copy, cache playback, row Delete, or Clear History is in scope.
- Do not read when: only provider retry, repair metadata, or accepted-history default is in scope.
- Maximum size: 100 physical lines.

## Window and ordering

- Menu exposes Transcript History and opening brings its window frontmost even
  when it already exists behind another app.
- Window title is `HoldType: History`; menu item and in-window heading may say
  `Transcript History`.
- Entries are newest-first by original recording creation time and may group by
  that time's day. Retry and state updates retain original position/day; update
  time never reorders the row.
- Each accepted row shows entry time and transcript text.

## Accepted-row playback and copy

- With Recording Cache enabled, accepted rows may offer Play only while their
  app-owned cached file exists.
- Cache off, clear, individual cache delete, or pruning removes Play availability.
- Accepted-row Play is local comparison only and never uploads, retries,
  updates Last Transcript, writes clipboards, or inserts text.
- Each row copies only its text to the macOS system clipboard. Copy ignores Keep
  last result, does not update Last Result, and does not insert into active app.

## Exact-row Delete

- Delete removes only that row and never Keychain, Settings, normal cache,
  cached playback files, Last Transcript, or other rows.
- Deleting failed or successful maximum-duration recovery also removes only its
  exact protected audio.
- UI reports success only after metadata and exact audio are both removed. If
  either fails, the row remains or reconstructs and a failure is shown.

## Clear History

- `Clear History` is destructive and enabled for any accepted entry or
  deletable Saved Recording, even with no accepted entries.
- Confirmation states it removes accepted entries plus recovery audio/metadata
  for deletable Saved Recordings and identifies active Processing rows kept.
- Clear removes every accepted entry and deletable shown Saved Recording; it
  never deletes Keychain, Settings, normal cache, or Last Transcript.
- Processing remains protected. Any incompletely deleted Saved Recording stays
  or reconstructs, and the result reports it was kept rather than false success.
- Main menu has no manual Save Last Transcript. When Keep last result is on,
  accepted transcripts save automatically under the output contract.

## Dependencies

- [Transcript History](../transcript-history.md) — shared deletion boundaries.
- [Text output](../text-output-workflow.md) — Last Result and system clipboard separation.
