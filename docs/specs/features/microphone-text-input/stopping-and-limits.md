# Microphone Stopping, Limits, and Finalization

- Node type: leaf
- Contract ID: `holdtype.macos.microphone-input.finalization`
- Domain ID: `holdtype.macos.microphone-input`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.microphone-input.finalization@1`
- Read when: stop tail, maximum duration, countdown, recorder completion, or exact-once finalization is in scope.
- Do not read when: only device selection, recovery retention, or output is in scope.
- Maximum size: 100 physical lines.

## Stop tail

- `Recording tail after release` keeps capture active for its selected fixed
  duration after stop. It defaults Off, never waits for detected silence,
  analyzes speech, or extends indefinitely.
- While the tail is pending, visible state remains recording. Repeated stops do
  not enqueue another delay, finalization, transcription, or output operation.

## Selected maximum and cues

- Each attempt freezes a user-selected maximum of 1–15 whole minutes, default
  five. Later Settings changes affect only the next attempt.
- Reaching the maximum is a normal automatic Finish: close the recorder,
  protect the completed non-empty artifact, and continue transcription exactly once.
- The final 15 seconds show whole seconds in a countdown. Warning milestones are
  60, 30, 10, 8, and 6 seconds, then every second from 5 through 1. With a
  one-minute maximum, countdown begins at 45 elapsed seconds and omits the
  60-second warning at start. A distinct stopped-at-limit cue follows recorder close.
- Audible warnings during capture use only a private route that cannot feed the
  microphone, such as headphones. Speaker routes use visual countdown and
  platform haptics without injecting sounds into retained audio.

## Exact-once finalization

- A controller-owned monotonic watchdog matching the frozen maximum requests
  finalization if the recorder completion delegate is lost. Watchdog, delegate,
  key-up, and stop race through one finalization boundary.
- Monotonic elapsed time or finalized media duration at the selected maximum
  remains authoritative even if the callback says `successfully = false`; log
  the anomaly without downgrading or deleting the limit-length recording.
- If key up wins, finalized media at or above one half-second below the frozen
  maximum retains maximum-duration identity despite callback scheduling.
- An early completion without limit evidence preserves any non-empty artifact,
  uses normal stop feedback, reports that recording ended unexpectedly and was
  saved to History, and starts no provider request unless user Finish already
  claimed authority. Its provider-free row offers explicit Transcribe and never
  claims the maximum elapsed.
- Stopping returns file URL, captured duration, and byte size before provider work.
- Finalized-duration inspection has a two-second maximum wait. Failure or
  ignored cancellation falls back to captured-duration metadata and never
  deletes a positive-byte artifact.
- A stopped recorder's volatile elapsed clock is not authoritative. Positive
  bytes are never deleted solely because that clock is zero or differs from media.

## Terminal media rules

- Missing, empty, or reliably measured sub-one-second audio is not completed:
  remove only the current app-created temporary artifact and return to Ready
  without status, History, provider, recovery, Retry, or Dismiss.
- Zero or unavailable duration alone cannot delete a positive-byte artifact
  that may meet the one-second minimum.
- No usable finalized file ends the attempt quietly without transcription,
  retry, recovery controls, error, or a false saved claim.

## Dependencies

- [Microphone input](../microphone-text-input.md) — shared exact-once rules.
- [Recording durability](../recording-durability-and-interruption.md) — partial preservation.
