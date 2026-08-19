# Microphone State, Failure, and Handoff

- Node type: leaf
- Contract ID: `holdtype.macos.microphone-input.state`
- Domain ID: `holdtype.macos.microphone-input`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.microphone-input.state@1`
- Read when: session serialization, provider eligibility, failure, or transcript handoff is in scope.
- Do not read when: only device selection, maximum-duration cues, or cache retention is in scope.
- Maximum size: 100 physical lines.

## Session flow

- Product states are idle, requesting permission, recording, transcribing,
  done, and error; recording, transcribing, done, and error remain mutually
  understandable.
- Start, stop, completion, and cancel serialize through one active session.
  Overlap may be ignored or visibly blocked but never queues duplicate recorder,
  provider, output, or accepted-transcript work.
- After capture stops, processing may continue while transcription completes.
- Processing has a configured timeout and fails with a visible recoverable error
  rather than waiting indefinitely.
- Success exposes the final transcript as Last Transcript and passes it once to
  the configured output workflow.
- A failed session never overwrites previously accepted text. A late result
  after cancellation or failure is discarded rather than accepted.

## Failure language and provider eligibility

- Failures use product language such as microphone unavailable, permission
  denied, no speech detected, or transcription timed out.
- Low-confidence or empty output is not presented as final useful text.
- Provider work begins only for an eligible, recovery-protected completed
  artifact; no raw audio is read into default logs.
- A maximum-duration Finish reports that the selected limit was reached and the
  recording was saved, then continues normal processing.

## Data implications

- Audio and raw transcription are ephemeral unless cache retention is enabled.
- An unfinished attempt's recovery checkpoint survives ordinary History/cache
  policy until transcription succeeds or the user explicitly deletes it.
- Successful maximum-duration Finish is a second bounded exception until
  explicit Delete or recovery-retention pruning.
- Capture uses unique local app-owned `.m4a` artifacts carrying file URL,
  duration, and byte count until stop, discard, retention, cleanup, or failure
  assigns the next state.
- A Dev Vlogs lease changes only ordinary cleanup timing for that exact artifact.

## Verification mapping

- Cover permission denial, unavailable and pinned inputs, disconnect, start,
  stop, cancel, timeout, empty speech/file, sub-one-second rejection, silent
  cleanup, retention, auto-Finish, warning cadence, duration inspection, false
  callbacks, exact-once finalization, recovery playback, and successful handoff.
- Use fakes or bounded fixtures for transcription rather than uncontrolled
  external waits.

## Dependencies

- [Microphone input](../microphone-text-input.md) — shared session invariants.
- [OpenAI transcription](../openai-transcription.md) — provider contract.
- [Text output](../text-output-workflow.md) — accepted result handoff.
