# iOS Voice Runtime State

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.runtime@1`
- Read when: phase, coarse stage, progress, or terminal outcome semantics matter.
- Do not read when: deciding durable resume solely from runtime values.
- Maximum size: 100 physical lines.

Phases: inactive, arming, historical ready, listening (includes tail), finalizing
(validation/identity/journal), processing (provider through result prep). Phase
does not erase setup/recovery/output. Usage bookkeeping is synchronous local,
nonfatal/nongating, never microphone/outcome/retry; persistence must be off
latency path before called nonblocking.

Stages are payload-free attribution, not ordered state/resume: recordingFinalization
(tail/stop/validation/pre-provider), transcription (prep/dispatch/validation/
acceptance, not proof network), postProcessing (intent/correction/local/translation/
validation), outputDelivery (after accepted text and durable phase, not proof
adapter/insertion). Carry no payload/authority and never start/authorize work.
Preflight has no stage.

Progress uses only stage, runtime non-Codable/no log/journal/bridge. Report only
after matching durable admission, each semantic stage once per invocation;
retained beginning reports none absent same live dispatch. Local recovery may
repeat stage across invocations without provider repeat. Separate kind is
processingCheckpoint or savingResult; final text cancellation preserves saving.
Reporter is nonthrowing presentation-only, ordered MainActor/current token,
cleared terminally. Transcription progress may expose Cancel but grants no authority.

Outcome exactly resultReady, recoverableFailure, interrupted. Result means safe
non-empty app text, not insertion. Recoverable requires retained eligible owner.
Interrupted is true audio/platform termination, not Cancel/preflight/limit.
Expiry/clock rollback are output observations, not outcome. No Quick Session
expiry. Outcome has no payload/retry/setup/log authority; Equatable/Sendable,
nonraw/non-Codable/runtime only.

Setup, active phase, outcome, and output-delivery observations remain independent;
UI projects one understandable state without collapsing them. Never label armed
mic inactive or setup-dependent ready.
