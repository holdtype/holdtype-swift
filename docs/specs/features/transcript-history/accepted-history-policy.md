# Accepted Transcript History Policy

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.accepted`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.accepted@1`
- Read when: accepted-history default, toggle, append, retention, or Last Transcript interaction is in scope.
- Do not read when: only saved-recording retry or History window actions are in scope.
- Maximum size: 100 physical lines.

## Default and toggle

- Accepted recovery history is local, durable across relaunch, enabled by
  default, and retains the 20 most recent accepted entries.
- One-time migration changes the legacy stored off default to on; later explicit
  user choices persist normally.
- Settings exposes `Keep Transcript Recovery History`.
- Turning it off immediately clears durable accepted entries and prevents
  future accepted writes. It does not delete unfinished or maximum-duration
  Saved Recordings.
- Turning it back on affects future successes and does not restore cleared text.
- Last Transcript remains current-session state independent of accepted history;
  the menu bar dropdown never displays transcript text.

## Accepted append and recovery exceptions

- With history enabled, every accepted non-empty transcript is durably appended
  after transcription succeeds and before active-app output can fail.
- Every non-empty recording creates a saved `Processing` checkpoint before
  provider work regardless of the accepted-history toggle.
- Automatic Finish at the configured maximum uses that same row and starts
  provider work exactly once.
- Its success becomes `Saved and transcribed`, includes accepted text, retains
  Play and explicit Delete, and never offers Retry.
- That row is the sole History row for the result; no duplicate accepted row is added.
- Maximum-duration row and audio survive relaunch, disabled/cleared accepted
  history, `Delete immediately` cache cleanup, and normal quit. Only explicit
  Delete or bounded recovery retention removes them.
- Unresolved Processing, failed, interrupted, internal-failure, and teardown
  rows are never count-evicted; only explicit Delete/Discard removes their audio.
- Recovery keeps max 20 accepted rows plus a small bounded set shared by recent
  failed and successful maximum-duration recordings. Older protected artifacts
  are removable automatically only after no provider owns them and the
  saved-recording limit is exceeded.

## Output boundaries

- Retry success updates Last Transcript and, when enabled, Last Result.
- Retry failure preserves previous successful Last Transcript.
- Failed insertion or Paste Last Result never discards accepted recovery or
  current Last Transcript.
- Empty or whitespace-only success creates no accepted row; provider empty
  failure may create a failed row when completed audio exists.

## Dependencies

- [Transcript History](../transcript-history.md) — shared recovery invariants.
- [Text output](../text-output-workflow.md) — Last Transcript and Last Result.
