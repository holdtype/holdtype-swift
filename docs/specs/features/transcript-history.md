# Transcript Recovery History

## Goal

Keep recent successful dictations recoverable during the current app session so
users do not need to re-dictate long text when active-app insertion fails, the
target input changes, or a completed recording fails to transcribe for a
recoverable provider or network reason.

## Decision

Transcript recovery history is in the MVP as a session-only local feature. It
is enabled by default because successful transcript entries are kept in app
memory only, are never written to disk for this slice, and are cleared when the
app quits.

Recoverable failed transcription attempts may also keep a bounded session-only
local audio artifact so the user can retry without re-recording. This is an
explicit recovery exception, not durable transcript persistence or the normal
recording cache.

Users can disable recovery history in Settings. Disabling it clears current
recovery entries and stops future history writes until it is enabled again.

Older local settings that stored the previous off-by-default value are migrated
once to the current on-by-default behavior. After that migration, a user's
explicit Settings toggle choice persists normally.

Last Transcript remains current-session state and does not require recovery
history to be enabled, but the menu bar dropdown does not display transcript
text.

## Scope

This spec covers:

- session-only storage of accepted transcript text
- session-only storage of recoverable failed transcription attempts
- default history setting
- retention limit and clear behavior
- history panel behavior
- history row system clipboard copy and deletion actions
- failed row retry and settings actions
- privacy and logging boundaries
- relationship to Last Transcript, Last Result, and system clipboard
  actions
- cache-gated local playback of completed recordings from history rows

## Non-goals

- durable disk-backed transcript persistence
- durable raw audio retention outside bounded failed-attempt recovery or the
  explicit normal recording cache setting
- cloud sync, accounts, sharing, or telemetry
- full search, semantic notes, tags, folders, or review workflows
- SQLite or another database requirement for the MVP
- storing cancelled, discarded, partial, or pre-capture setup failures

## User-visible behavior

- Transcript recovery history is on by default for the current app session.
- Existing installs that still carry the legacy off default are switched on
  once during settings load.
- Settings exposes a Keep Transcript Recovery History toggle.
- Turning recovery history off immediately clears current history entries and
  stops future history writes.
- Turning recovery history back on affects future successful dictations. It
  does not restore entries cleared earlier.
- When recovery history is on, each accepted non-empty transcript is added to
  recovery history after transcription succeeds and before active-app output
  handoff can fail.
- When recovery history is on, a completed recording that fails during
  transcription for a recoverable OpenAI, network, timeout, rate-limit,
  unreadable-response, or empty-result reason is added to recovery history as a
  failed attempt.
- The immediate user-facing failure surface for a completed recording is the
  menu bar recovery prompt. Transcript History is the session recovery surface
  the user can open from the normal menu item.
- A failed attempt row must be visually distinct from accepted transcript rows.
  It should show `Not transcribed`, a compact reason, the attempt time, and any
  known duration/model/language metadata.
- A failed attempt row may offer Retry. Retry sends the saved temporary audio
  through the current transcription settings and current API key.
- A failed attempt row caused by invalid or unavailable API key should offer an
  Open API Key Settings action and may also allow Retry after the user fixes the
  key.
- A failed attempt row caused by invalid transcription settings should offer an
  Open Transcription Settings action and may also allow Retry after the user
  fixes the settings.
- Retry success replaces the failed attempt with a normal accepted transcript
  history row and updates Last Transcript. If Keep last result is enabled,
  the recovered transcript is saved there for manual insertion.
- Retry failure keeps the failed attempt row, updates its reason and retry
  count, and keeps the previous successful Last Transcript intact.
- A failed automatic insertion or Paste Last Result must not discard the
  current Last Transcript or the recovery history row created for the accepted
  transcript.
- Recovery history keeps at most the 20 most recent accepted transcripts and a
  small bounded set of recent failed transcription attempts. Older failed
  attempts and their temporary audio artifacts are removed automatically when
  the failed-attempt limit is exceeded.
- The menu bar exposes a Transcript History window.
- Opening Transcript History brings the window to the front, including when it
  already exists behind another app window.
- The Transcript History window title should identify the app as
  `HoldType: History`. The menu bar item and in-window heading may remain
  `Transcript History`.
- The Transcript History window lists entries newest-first and may group them
  by day.
- Each history row shows the entry time and transcript text.
- When Recording Cache is enabled, an accepted transcript row may offer Play for
  the completed recording that produced that row, but only while the app-owned
  cached recording file still exists.
- The Play action is a local debugging aid for comparing audio with the accepted
  transcript. It must not upload audio, retry transcription, update Last
  Transcript, write to either clipboard, or trigger active-app insertion.
- Turning Recording Cache off, clearing the cache, deleting a cached recording,
  or retention pruning the file must remove Play availability for affected
  accepted transcript rows.
- Each history row can copy only that row's text to the macOS system clipboard.
- History row system clipboard copy does not require the Keep last result
  setting, does not update the Last Result recovery value, and does not
  trigger active-app insertion.
- Each history row can delete only that row from current recovery history.
- The history window provides a Clear History action.
- Deleting one history row removes only that row. It does not delete Keychain
  secrets, settings, normal recording cache state, cached recordings linked for
  local playback, Last Transcript current-session state, or other history rows.
  Deleting a failed attempt also removes only that failed attempt's temporary
  retry audio.
- Clearing history removes only current recovery history entries. It does not
  delete Keychain secrets, settings, normal recording cache state, or Last
  Transcript current-session state. Clearing history also removes temporary
  failed-attempt retry audio.
- Quitting the app clears current recovery history entries.
- The main menu does not provide a manual Save Last Transcript action. When
  Keep last result is enabled, accepted transcripts are saved there
  automatically under `text-output-workflow.md`.

## Stored fields

Each accepted transcript history entry should store only:

- stable local id
- creation date
- transcript text
- transcription model
- language setting used for the request
- optional audio duration, if already known from the completed session
- optional session-only reference to an app-owned normal recording cache file
  for local playback, only when Recording Cache was enabled for that completed
  recording

History must not store raw audio, provider responses, authorization headers,
API keys, prompt text, custom dictionary entries, or debug payloads. Any
recording cache file reference on an accepted row is session-only metadata for
local playback and must not be persisted with transcript history.

Each failed attempt entry should store only:

- stable local id
- creation date
- compact failure reason
- retry count
- transcription model
- language setting used for display
- optional audio duration, if already known from the completed session
- temporary app-owned audio file reference needed for retry

Failed attempt entries must not store provider responses, authorization
headers, API keys, prompt text, nearby active-text context, custom dictionary
entries, transcript text, or debug payloads.

## Privacy and storage

- Recovery history is local-only and session-only for this MVP slice.
- Recovery history metadata must not be persisted to UserDefaults, local JSON,
  SQLite, or another disk-backed store.
- Temporary failed-attempt audio is local-only, session-only, app-owned, and
  retained solely so the user can explicitly retry transcription.
- No history entry may be sent to a server except when the user later uses a
  separate feature that explicitly sends text and has its own spec.
- Default logs must not include transcript text or history entry contents.
- Default logs must not include recording cache paths, failed-attempt audio
  paths, playback paths, or retry payloads.
- Durable persistent transcript history requires a future spec update before
  implementation.

## Edge cases and failure policy

- Empty or whitespace-only successful transcript text must not create accepted
  transcript entries. Provider empty-result failures may create failed attempt
  entries when completed audio exists.
- Cancelled recordings must not create history entries.
- Pre-capture setup failures such as a missing API key must not create failed
  attempt entries because no completed audio exists.
- If a failed attempt's temporary audio cannot be saved, the app should still
  show the immediate transcription error but must not show a fake Retry action.
  It must skip destructive recording-cache cleanup for that attempt so the
  completed artifact remains recoverable where possible.
- If a history append fails, the app should keep the current Last Transcript
  visible and continue output delivery where practical.
- If a cached recording is missing or cannot be played, the history row should
  stop offering Play or report a compact playback failure without logging the
  file path.
- If the app terminates normally, recovery history is cleared during shutdown.

## Verification mapping

- Settings tests should prove recovery history is enabled by default,
  disabling it clears current entries, and the setting persists.
- History tests should cover accepted append, max-20 accepted retention, failed
  attempt append, failed-attempt retention and audio cleanup, clear,
  disabled-no-write behavior, row deletion, cache-gated local playback
  availability, retry success, retry failure, and exclusion of cancelled or
  pre-capture setup failures.
- Controller tests should prove output failure does not erase accepted recovery
  history.
- Log review should confirm transcript history contents are not emitted in
  default logs.
