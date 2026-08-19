# History Repair and Relaunch

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.repair`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.repair@1`
- Read when: persistence failure, repair metadata, orphan reconstruction, relaunch, or recovery verification is in scope.
- Do not read when: only normal row interaction or accepted-history toggle is in scope.
- Maximum size: 100 physical lines.

## Accepted-state repair

- Before Processing becomes `Saved and transcribed`, atomically write bounded
  repair metadata with accepted text and protected-audio identity.
- If main transition then fails, do not publish false saved state or repeat
  provider work. Show visibly incomplete row with Play and local Retry Save only.
- Successful repair-write classification and text survive relaunch; startup
  restores incomplete, hides provider Retry, and never converts post-success
  uncertainty into retryable transcription. Local repair removes temporary metadata.
- If both repair and main-index writes fail after provider success, keep text in
  memory for the process. Relaunch uses the dispatch seal to restore playable
  outcome-uncertain with provider Retry permanently hidden, never claiming text
  was durably saved.

## Checkpoint and orphan reconstruction

- If main Processing checkpoint write fails after audio copy, bounded metadata
  preserves maximum-duration identity. Before relaunch the same checkpoint
  provides an emergency row; provider success makes it non-retryable even if
  saved-state transition also fails.
- Missing/corrupt compact metadata reconstructs a bounded set from app-owned
  non-empty `Recording-<timestamp>-<UUID>` and
  `Recording-Max-<timestamp>-<UUID>` files, then repairs metadata atomically.
- Max filename preserves configured-limit retention if both checkpoint writes fail.
- Reconstruction never follows symlinks and ignores directories, special files,
  malformed names, and unmanaged files.

## Other edge cases

- Failed history append keeps Last Transcript visible and continues output where practical.
- Missing/unplayable normal cache file removes Play or reports compact failure
  without logging its path.
- Invalid saved-recovery audio is excluded and cannot upload or retry.
- Normal termination preserves accepted, unfinished, and successful
  maximum-duration recovery across relaunch.

## Verification mapping

- Settings: default-on, one-time migration, disable/clear, and persistence.
- History: accepted append/relaunch/max-20, row delete/clear, failed retention,
  saved-row round-trip, disable survival, cache-gated Play, retry outcomes,
  checkpoint failure, fail-closed repair, local Retry Save, and exclusions.
- Controller: output failure does not erase accepted recovery.
- Logs: no transcript or History content in default output.

## Dependencies

- [Transcript History](../transcript-history.md) — shared repair truthfulness.
- [Dispatch seals](dispatch-seals-and-retry.md) — fail-closed provider authority.
