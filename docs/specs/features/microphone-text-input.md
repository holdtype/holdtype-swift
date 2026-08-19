# Microphone Text Input

- Node type: hybrid
- Contract ID: `holdtype.macos.microphone-input`
- Domain ID: `holdtype.macos.microphone-input`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.microphone-input@1`
- Read when: starting, stopping, finalizing, recovering, or caching macOS microphone capture is in scope.
- Do not read when: only provider HTTP, global shortcut registration, or transcript persistence is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

HoldType records explicit macOS microphone input into a temporary local audio
artifact, sends eligible completed audio to OpenAI transcription, and hands the
result to the output workflow.

This domain owns capture start/stop/discard, device selection, visible capture
and processing states, finalization, maximum duration, recovery checkpoints,
cache policy, failure behavior, and session-level exact-once boundaries.

## Non-goals

- Exact OpenAI HTTP behavior, global shortcut registration, transcript-history
  presentation, final UI styling, or app architecture.
- Streaming or live partial transcription.

## Children

- [Devices and permission](microphone-text-input/devices-and-permission.md) —
  explicit start authority, system-default or pinned input, and unavailable or
  disconnected-device behavior.
- [Stopping, limits, and finalization](microphone-text-input/stopping-and-limits.md) —
  tail delay, selected maximum, warning cadence, watchdog, and exact-once finalization.
- [Durability, recovery, and cache](microphone-text-input/durability-and-recovery.md) —
  explicit discard, recovery copy, Dev Vlogs read lease, and recording retention.
- [State, failure, and handoff](microphone-text-input/state-failure-and-handoff.md) —
  serialization, provider eligibility, failure policy, output, and session data.

## Shared invariants

- No background or hidden recording and no parallel recording attempts.
- Internal cancellation, lifecycle teardown, and errors are never destructive
  user authority; only explicit Discard deletes the current qualifying artifact.
- Recorder completion, deadline, stop, and key-up paths share one exact-once
  finalization boundary and cannot duplicate provider or output work.
- External provider or media work has an explicit maximum wait.
- Every attempt follows
  [recording durability and interruption](recording-durability-and-interruption.md).

## Dependencies

- [Recording durability and interruption](recording-durability-and-interruption.md) — interruption and artifact-preservation authority.
- [OpenAI transcription](openai-transcription.md) — provider request and timeout behavior.
- [Text output](text-output-workflow.md) — accepted transcript handoff.
- [Transcript History](transcript-history.md) — recovery checkpoint presentation and deletion.
- [Settings and secrets](settings-and-secret-storage.md) — device, duration, tail, and retention settings.
- [Dev Vlogs](dev-vlogs.md) — bounded finalized-audio read lease.

## Unknowns

- Deployment target remains macOS 14 Sonoma and newer pending confirmation.
- Exact OpenAI model, timeout target, first-version languages, and whether
  hold-to-record is mandatory for MVP remain open.
