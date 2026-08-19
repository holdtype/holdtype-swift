# iOS Handoff and Dev Vlogs Durability Boundaries

- Node type: leaf
- Contract ID: `holdtype.shared.recording-durability.consumers`
- Domain ID: `holdtype.shared.recording-durability`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.recording-durability.consumers@2`
- Read when: iOS capture cancellation/handoff or Dev Vlogs media separation is in scope.
- Do not read when: only macOS terminal classification or History actions are in scope.
- Maximum size: 100 physical lines.

## iOS cancellation and handoff

- App Group publication failure affects coordination UI only and never cancels
  or discards the recorder.
- Swift task cancellation, controller deinit, scene replacement, and handoff
  supersession map to `ownerTeardown`, not `explicitUserDiscard`.
- Once a byte may exist, arming races preserve Done, configured-limit,
  interruption, or teardown cause rather than collapsing to Cancelled.
- New keyboard handoff checks live/durable ownership, not presentation phase,
  and supersedes only proven pre-capture or empty attempts.
- `Stop Keyboard Session` while Listening finalizes non-empty partial audio to
  provider-free Saved Recording. During Finalizing or Processing it disarms
  warm session without cancelling owned finalization or provider work.
- Closing a handoff surface after capture starts is not destructive authority.
- Losing an auxiliary warm-input keeper disables warm reuse, not active recording.
- Scene inactivity alone is not failure. Stop occurs only when platform/audio
  cannot continue, or after Finish, configured limit, or explicit Discard;
  impossible continuation preserves a `platformInterrupted` partial.

## Dev Vlogs media boundary

- `DV-DURABILITY-1`: Camera video, source clips, fragments, manifests, and Build
  have separate Dev Vlogs ownership and never become dictation History, cache,
  or provider-retry audio.
- `DV-DURABILITY-2`: Interruption preserves recoverable fragments under that
  owner and truthfully yields Ready, Incomplete, or Failed without changing
  dictation. Relaunch validates local vlog archive and never uploads recovery.
- `DV-DURABILITY-3`: Only explicit Dev Vlogs Delete removes retained vlog media.
  V1 has no automatic retention deletion; History/cache/dictation cleanup and
  unrelated teardown never delete it.
- `DV-DURABILITY-4`: Active, finalizing, recovering, or Build-owned media cannot
  be deleted. Exact clip/media deletion never removes dictation owners, History,
  cache, exports, or unrelated files.

## Verification

Fault injection covers publication/arming races, task cancellation, handoff
supersession, warm-input failure, and separate vlog finalization ownership.

## Dependencies

- [Recording durability](../recording-durability-and-interruption.md) — shared cause and ownership rules.
