# Microphone Text Input

## Goal

Define the first user-visible contract for turning microphone input into text
inside the HoldType macOS menu bar app.

The MVP records speech from the microphone, sends the temporary audio file to
the OpenAI transcription API, and makes the returned text available to the
output workflow.

## Scope

This spec covers:

- starting and stopping a microphone text-input session
- visible recording and processing states
- temporary audio capture
- OpenAI transcription result handoff
- cancellation and failure behavior
- recording cache retention and cleanup behavior
- session-level state transitions

## Non-goals

- defining the exact OpenAI HTTP contract
- defining global shortcut registration details
- defining transcript history or persistence
- defining final UI layout, styling, or app architecture

## User-visible behavior

- The app must not capture microphone input until the user takes an explicit
  start action and required permissions are available.
- Skipping a setup prompt for microphone permission may dismiss that prompt for
  the current app run, but it must not count as microphone consent and must not
  let recording start while microphone permission is missing.
- A recording start action may prepare a temporary local audio file only after
  microphone permission is allowed.
- Start/stop must be available from the menu bar menu.
- A global hotkey should start and stop recording once the hotkey feature is
  implemented.
- While microphone capture is active, the app must show an unmistakable
  recording state.
- The user must be able to stop an active recording session.
- When `Recording tail after release` is enabled in Settings, a stop action
  keeps microphone capture active for the selected fixed tail duration before
  the completed recording file is finalized. The default tail setting is Off.
- The recording tail is a fixed delay only. It must not wait for detected
  silence, analyze speech, or extend indefinitely.
- A single recording attempt must have a bounded MVP maximum duration of five
  minutes. When the limit is reached, capture stops at the recorder boundary
  and the session fails with a recoverable maximum-length message instead of
  sending the timed-out artifact to transcription.
- Stopping an active recording returns a completed local recording artifact
  with the file URL, captured duration, and byte size before transcription may
  begin.
- The user must be able to cancel a session before accepting or handing off the
  generated text.
- Cancelling active capture stops the recorder, removes the current app-created
  temporary audio artifact, returns the session to idle, and must not start
  transcription or output handoff.
- Cancelling during the recording tail must cancel the pending stop delay,
  stop and remove the current recording artifact, and must not start
  transcription or output handoff.
- After capture stops, the app may enter a processing state while
  transcription completes.
- Start, stop, and cancel actions must be serialized through one active
  session. Repeated or overlapping actions may be ignored or shown as blocked,
  but must not enqueue duplicate recorder, transcription, or output work.
- While a recording tail is pending, the user-visible state remains recording.
  Repeated stop actions must not enqueue duplicate stops or transcription work.
- Processing must not wait indefinitely. If transcription cannot finish within
  the configured timeout, the session fails with a visible, recoverable error.
- A successful session must expose the final transcript as the last transcript
  and pass it to the configured output workflow.
- Streaming or live partial transcription is not part of the MVP.
- Failure states should explain the immediate problem in product language, such
  as microphone unavailable, permission denied, no speech detected, or
  transcription timed out.
- The completed recording file remains a temporary app-owned audio artifact. By
  default, HoldType deletes it after the current attempt finishes.
- If the user explicitly enables recording cache retention in Settings, HoldType
  may keep completed `.m4a` recordings after transcription so the user can open
  or save them from Finder.
- The recording cache should default to keeping only the 10 most recent
  recordings when retention is enabled. The user may switch retention to
  unlimited, in which case Settings must make clear that the user is
  responsible for clearing the cache.
- Settings must show the current recording cache size on disk and provide a
  clear action for app-owned cached recordings.

## Invariants

- No background or hidden recording is allowed.
- Repeated start actions must not create parallel recordings.
- Repeated stop or completion actions must not produce duplicate transcription
  uploads, duplicate output handoffs, or multiple accepted transcripts for one
  recording.
- Stopping or cancelling capture must not silently accept unfinished text.
- Cancelling capture must clean up only the current recording artifact and must
  leave unrelated temporary files untouched.
- A failed session must not overwrite previously accepted text.
- Recording, transcribing, done, and error states must be mutually
  understandable to the user.
- External transcription or media operations must have explicit maximum wait
  times.
- Recording cache growth must be bounded by default. The app must not keep
  accumulating audio files indefinitely unless the user explicitly chooses
  unlimited retention.

## Edge cases and failure policy

- If microphone permission is denied, the app should explain that microphone
  access is required and provide a path to retry after the user changes
  permissions.
- If no microphone is available, the app should fail before entering a false
  recording state.
- If the user stops recording immediately, the app should either produce an
  empty/no-speech result or a clear no-input message.
- If transcription produces low-confidence or empty output, the app should not
  pretend the result is final useful text.
- If a late transcription result arrives after cancellation or failure, it must
  be discarded rather than accepted as a new last transcript.
- If the app is interrupted by platform lifecycle events, the session should
  stop or fail visibly rather than continue recording invisibly.
- If the recording is too short, the app should show a clear error instead of
  sending misleading empty input through the normal success path.
- If the recording reaches the maximum duration, the app should stop or fail
  the capture and show a clear maximum-length error without uploading the
  timed-out artifact.
- Missing, empty, too-short, or maximum-duration completed recording artifacts
  must be treated as failed recording results and must not be sent to OpenAI.
- Turning off recording cache retention affects future attempts immediately:
  completed recordings from those attempts are deleted after the attempt
  finishes, whether transcription succeeds or fails.

## Route / state / data implications

The product-level session states are:

- idle
- requesting permission
- recording
- transcribing
- done
- error

Audio and raw transcription artifacts are treated as ephemeral session data
unless recording cache retention is explicitly enabled in Settings.
The recording service should create unique app-owned temporary `.m4a` audio
artifacts for capture attempts and keep those paths local to HoldType until
stop, cancel, cache retention, cleanup, or failure handling decides their next
state.
Completed recording artifacts carry file URL, duration, and byte-count metadata
so downstream transcription can validate input without reading raw audio into
default logs.

## Verification mapping

- Add tests or manual QA for permission denied, microphone unavailable,
  start/stop, cancel, timeout, empty speech, recording-too-short, temp-file
  cleanup, recording cache retention, and successful transcription states when
  implementation code exists.
- Use fakes or bounded local fixtures for transcription tests instead of
  waiting on uncontrolled external services.

## Unknowns requiring confirmation

- Deployment target: macOS 14 Sonoma and newer.
- Exact OpenAI transcription model and timeout target.
- Supported languages for the first version.
- Whether hold-to-record is mandatory for MVP or toggle mode is acceptable
  first.
