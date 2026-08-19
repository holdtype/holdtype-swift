# Microphone Durability, Recovery, and Cache

- Node type: leaf
- Contract ID: `holdtype.macos.microphone-input.recovery`
- Domain ID: `holdtype.macos.microphone-input`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.microphone-input.recovery@1`
- Read when: explicit discard, recovery audio, Dev Vlogs lease, or cache retention is in scope.
- Do not read when: only device selection, countdown, or provider response is in scope.
- Maximum size: 100 physical lines.

## Explicit discard

- The user may explicitly discard before accepting or handing off generated
  text. The destructive action is labelled Discard/Cancel Recording and is
  never inferred from task cancellation, lifecycle teardown, internal error,
  or closing another surface.
- Discard during capture stops the recorder, removes only the current
  app-created artifact, returns idle, and starts no transcription or output.
- Discard during stop tail also cancels the delay. A non-user interruption in
  the same interval preserves positive bytes under the durability contract.
- Cancellation never deletes unrelated temporary files or accepts unfinished text.

## Recovery checkpoint

- Before any provider request, completed audio of at least one second becomes
  an app-owned local History checkpoint with Play. It is labelled processing;
  after transcription failure it retains Transcribe/Retry and Delete.
- If an app-owned recovery copy cannot first be created, the original remains
  playable and deletable but cannot be uploaded. History offers local Retry
  Save/Repair; provider Retry appears only after repair succeeds.
- Successful automatic Finish at the configured maximum becomes a durable
  `Saved and transcribed` row with accepted text. Its protected audio is
  playable and explicitly deletable but never retryable.
- Active, finalizing, and unresolved recovery audio is not ordinary cache.
  Cache Clear, individual Delete, and retention pruning exclude it.

## Dev Vlogs read lease

- `DV-AUDIO-LEASE-1`: A shipping Dev Vlogs finalizer may receive one bounded
  read lease on the finalized authoritative dictation artifact. It owns no
  capture or second artifact, cannot delay provider work indefinitely, and
  changes neither provider eligibility nor output exact-once behavior.
- `DV-AUDIO-LEASE-2`: Ordinary cleanup cannot delete the leased artifact.
  Release occurs on success, skip, timeout, cancel, finalization failure, and
  owner teardown. Vlog failure affects only the vlog branch.
- The lease is ephemeral attempt state: no transcript persistence, duplicate
  capture, or transfer of dictation ownership into the vlog archive.

## Ordinary recording cache

- Completed capture is temporary and deleted after the attempt by default.
  Automatic-Finish cleanup deletes the original while preserving its separate
  bounded History recovery copy.
- When retention is enabled, completed `.m4a` files may remain after
  transcription for Finder access or save.
- Retention defaults to the 10 most recent recordings. Unlimited retention is
  explicit and Settings states that the user must clear it.
- Settings shows current cache size and provides a clear action for app-owned
  cached recordings.
- Turning retention off affects future attempts immediately, deleting their
  completed recordings after success or failure.
- Default cache growth is bounded; unlimited growth requires explicit choice.

## Dependencies

- [Microphone input](../microphone-text-input.md) — shared ownership boundary.
- [Recording durability](../recording-durability-and-interruption.md) — non-destructive interruption.
- [Transcript History](../transcript-history.md) — recovery rows and deletion.
- [Dev Vlogs](../dev-vlogs.md) — lease consumer.
