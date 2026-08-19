# iOS V1.1 Recording Cache And Playback

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.recording-cache@1`
- Read when: retained accepted audio, playback, or retention policy matters.
- Do not read when: only text History or canonical Pending behavior matters.
- Maximum size: 100 physical lines.

- Cache is app-private, independent of text History, and off by default. New,
  missing, pre-field, or `deleteImmediately` settings resolve off; saved bounded
  or unlimited remains. Explicit enabling starts at 20 newest recordings;
  unlimited requires explicit choice.
- Under a retaining policy, cache validated Pending audio by accepted `resultID`
  before cleanup. Relaunch is idempotent and never repeats provider work.
- Cache read/write/retention failure never converts accepted dictation to
  failure or blocks accepted Pending cleanup; later reconciliation may retry.
- Limit-ended success publishes to managed `saved-v1-*` before unlinking the
  only Pending source. Publish failure leaves `acceptedCleanup` and source,
  shows no false Saved Recording, and retries local publish/cleanup after relaunch.
  Done racing watchdog cannot downgrade ownership: finalized duration within
  500 ms of frozen boundary gets the same protected retention.
- Show row Play only while cache enabled and exact file exists. Saving off
  immediately reconciles managed files; clear/prune removes availability.
  Enabling affects future results; never reconstruct/re-upload old audio.
- Playback is local: no OpenAI/retry, Latest/History mutation, clipboard, or
  insertion. Deleting a History row does not delete independent cache audio;
  cache retention/clear owns files, matching macOS.
- One process player owns playback. Starting Voice stops it and deactivates
  playback audio session before recording activation. Missing/unplayable files
  remove Play or show compact failure; never expose paths in logs/UI.
