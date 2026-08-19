# iOS Voice Flow And Cleanup

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-state.flow@1`
- Read when: processing Pending, Retry/Discard, acceptance, or cleanup.
- Do not read when: only launch-time orphan classification matters.
- Maximum size: 100 physical lines.

- Capture becomes Pending before provider. Limit Finish follows the same path
  and starts normal provider exactly once. One Pending blocks another recording.
- Provider failure preserves exact audio. Offer Retry only for a confirmed-safe
  stage; unknown outcome offers Play/Discard. UI may receive opaque Play, never URL.
- Cancellation never silently discards recoverable Pending. Retry is explicit,
  finishes from local checkpoint or uses current setup only for next safe stage,
  and never repeats completed/unknown provider work. Discard removes exact
  Pending only, never Latest/History.
- Commit Latest before History. History failure warns nonblockingly; always
  continue Pending cleanup whether History succeeds, is off, or fails.
- Protected limit-ended success publishes exact audio to bounded `saved-v1-*`
  before unlink. Publish failure leaves `acceptedCleanup` and source; Latest may
  be ready but no false Saved Recording appears.
- Retained copy owns audio only after result identity, protected namespace,
  extension, and byte count match and bounded-set reconciliation succeeds.
  Reconciliation failure preserves cleanup. If unlink succeeds but final
  metadata write fails, relaunch accepts absent Pending source, keeps playable
  Saved Recording, and finishes metadata only.
- After Latest commit, cleanup failure never hides/rolls back result. Warn
  nonblockingly and retry only local cleanup later.
- Latest has no user Clear. Only newer accepted replacement or fail-closed
  proven invalidation changes it, without changing unrelated Pending.
