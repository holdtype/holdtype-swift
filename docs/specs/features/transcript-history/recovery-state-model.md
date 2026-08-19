# Recovery State Model and Actions

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.states`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.states@1`
- Read when: saved-row state, visible action, playback, processing, or concurrent dictation is in scope.
- Do not read when: only persistence repair, privacy fields, or accepted-history toggle is in scope.
- Maximum size: 100 physical lines.

## User-facing states

- `Saved and transcribed`: text available; Copy and Delete; Play only while the
  linked audio passes saved-recording validation; no transcription retry.
- `Transcribing…`: provider owns the saved recording; no Play, Retry,
  Transcribe Again, or Delete; every owned attempt must leave this state.
- `Not transcribed`: plain actionable reason; one `Retry Transcription` when
  current settings permit, plus applicable Settings, Play, and Delete; never
  Transcribe Again.
- `Transcription outcome uncertain`: explains possible prior acceptance and
  duplicate risk; one `Transcribe Again…`, Play, and Delete; never ordinary
  Retry. Confirmation repeats duplicate risk before submission.
- `Recording unavailable`: terminal local-artifact classification, excluded
  from History, with message `This saved recording can’t be opened, so it can’t
  be played or transcribed.` It offers no action and deletion requires separate authority.

## Row presentation and actions

- Failed rows are visually distinct, show `Not transcribed`, compact reason,
  attempt time, and known duration/model/language.
- Processing and failed rows offer local-only Play when audio is readable and
  no dictation is recording or processing. Play never uploads, starts/cancels
  provider work, updates Last Transcript, writes a clipboard, or inserts text.
- Starting recording stops saved/cache playback before microphone activation.
- Retryable rows show one labelled Retry; uncertain rows show one labelled
  Transcribe Again, never both or an unexplained icon.
- Retry/Transcribe Again validates the exact retained file before changing
  state, creating scratch data, or contacting provider. Invalid audio blocks
  start, records Recording unavailable, excludes the row, and shows its message.
- Invalid/unavailable API key offers Open API Key Settings; invalid
  transcription settings offers Open Transcription Settings. Retry may follow repair.

## Concurrency and deletion gates

- Play, Retry, and Delete are unavailable during another recording or provider
  operation. Controller independently rejects a Retry race so UI cannot move
  shared status away from Listening while capture is live.
- A Processing row cannot be deleted; provider ownership continues until saved
  or failed/deletable.
- Immediate completed-recording failure appears in menu recovery; History is
  the durable surface opened through the normal menu item.

## Dependencies

- [Transcript History](../transcript-history.md) — shared row truthfulness.
- [Dispatch seals](dispatch-seals-and-retry.md) — Retry and uncertainty authority.
