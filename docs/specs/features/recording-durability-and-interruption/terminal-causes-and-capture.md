# Recording Terminal Causes and Capture Ownership

- Node type: leaf
- Contract ID: `holdtype.shared.recording-durability.terminal`
- Domain ID: `holdtype.shared.recording-durability`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.recording-durability.terminal@2`
- Read when: terminal-cause classification, artifact ownership, finalization, quit, or relaunch is in scope.
- Do not read when: only iOS handoff presentation or saved-row actions are in scope.
- Maximum size: 100 physical lines.

## Closed cause set

Every terminal event has exactly one cause:

- `userFinished`: the user requests transcription.
- `configuredLimit`: the frozen selected limit ends capture and requests transcription.
- `platformInterrupted`: OS, audio route, recorder, or lifecycle prevents continuation.
- `internalFailure`: state publication, metadata finalization, or another local operation fails.
- `ownerTeardown`: controller/task cancellation or replacement, or process termination.
- `explicitUserDiscard`: the user explicitly asks to delete current audio.

Only `explicitUserDiscard` intentionally deletes retained non-empty audio. A
descriptor/file-handle-proven zero-byte source may be cleanup-only without user
action. A feature-defined sub-threshold app-created artifact is likewise
cleanup-only before durable ownership begins. Every other cause preserves
positive bytes under one durable owner.

## Capture ownership

- Durable attempt identity and ownership exist before the recorder may retain audio.
- Before a recovery checkpoint, active macOS capture and journal live in
  non-purgeable Application Support. Purgeable cache is never the sole owner;
  an original moves there only after separate durable History ownership commits.
- Active and finalizing audio is protected from cache Clear, individual Delete,
  and retention pruning.
- Stop, completion, deadline, lifecycle, and delegate callbacks race through one
  exact-once terminal boundary.
- Finalization error keeps a recoverable handle or path. Duration, media probe,
  metadata read, and state publication never authorize hiding or deleting bytes.
- Normal quit and updater relaunch request bounded finalization. If exit wins,
  launch repair promotes journaled positive bytes to provider-free Saved Recording.
- Crash, force quit, or OS eviction may delay notice, but next launch recovers
  the same source without automatic upload.

## Verification

- Positive bytes yield exactly one playable owner unless explicit Discard or a
  feature-defined sub-threshold non-recording applies.
- Zero-byte cleanup never touches another attempt.
- Involuntary/internal termination dispatches no provider unless Finish or the
  configured limit already owned that authority.
- Fault injection covers finalization, metadata/state publication, cache
  operations, normal quit, updater relaunch, process loss, and History failure.

## Dependencies

- [Recording durability](../recording-durability-and-interruption.md) — shared invariants.
