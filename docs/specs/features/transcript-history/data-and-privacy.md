# History Data and Privacy

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.data`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.data@1`
- Read when: persisted fields, local-only storage, logging, or privacy is in scope.
- Do not read when: only row presentation, provider state, or deletion interaction is in scope.
- Maximum size: 100 physical lines.

## Accepted transcript fields

Store only stable local ID, creation date, transcript text, transcription model,
request language, optional known duration, and an optional session-only
reference to the app-owned normal cache file when cache was enabled.

Accepted history stores no raw audio, provider response, authorization header,
API key, prompt, custom dictionary, or debug payload. Cache-file references are
session-only playback metadata and are not persisted with transcript history.

## Saved recording fields

Store only stable local ID, creation date, compact failure reason, retry count,
model, display language, optional known duration, temporary app-owned retry
audio reference, optional accepted text only after successful maximum-duration
transcription, and completion kind distinguishing normal from configured-limit Finish.

Saved rows store no provider response, authorization header, API key, prompt,
nearby active-text context, custom dictionary, rejected candidate, or debug payload.

## Privacy and storage

- Accepted text is local-only, max-20, and durable across relaunch.
- Recovery audio/metadata is local, app-owned, and bounded. Unfinished rows
  persist to success or explicit deletion; successful maximum-duration rows
  retain accepted text only to explicit Delete or recovery pruning.
- No history is sent to a server except through a separate explicitly specified feature.
- Default logs contain neither transcript/history content nor cache, recovery,
  playback, or retry paths/payloads.
- Unbounded or cloud-synced history requires a future specification change.

## Dependencies

- [Transcript History](../transcript-history.md) — shared local-only boundary.
