# iOS V1.1 Pending And Latest

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.pending-latest@1`
- Read when: one recoverable recording or internal accepted-result state matters.
- Do not read when: only accepted History or keyboard projection matters.
- Maximum size: 100 physical lines.

## Pending

- Store at most one attempt: stable `attemptID`, protected audio, compact
  app-private metadata; states are ready, processing, failed, and
  accepted-with-result while exact audio cleanup is unfinished.
- Relaunch reconciles locally only. Recoverable Pending offers Retry and Discard.
  History may show it separately as `Saved Recording` with Play,
  `Transcribe`/`Retry`, and Delete; it is no accepted row or failure queue.
- Never silently delete bounded non-empty finalized audio because a duration
  probe is under 300 ms, over the finalized-media bound, invalid, or timed out.
  Use frozen monotonic live elapsed clamped to the bound; absent that, keep
  unknown duration visible after relaunch with Play, explicit Transcribe/Retry,
  and Discard. Unknown duration never auto-starts provider work; after explicit
  success retain it in bounded Saved Recordings regardless of Recording Cache.
- Retry is explicit, uses current setup, and creates one fresh provider attempt
  only after local ownership. Discard removes exact audio/metadata without
  affecting Latest or History. Uncertain/corrupt state fails visibly and
  preserves data unless safe absence is proven. Pending audio blocks a second recording.

## Latest Result

- Store one accepted text, result ID, and source attempt ID app-privately; no
  provider payload, prompt, credential, or raw audio.
- It is internal acceptance/recovery, not a Voice card. Draft and compact
  History present accepted text. No direct Latest Copy, Share, Practice, or
  Clear; Draft and History actions mutate only their own records.
- Preserve across relaunch until replacement or fail-closed reconciliation
  proves invalid. Remove the old 24-hour expiry. Latest is always on; scoped
  migration ignores/removes the iOS `keepLatestResult` UI preference without
  changing macOS.
- Keyboard `Latest` derives from accepted History, not this record.
