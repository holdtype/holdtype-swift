# iOS History And Storage

- Node type: hybrid
- Status: Historical; superseded for V1.1
- Read when: reviewing the retired P4/P5H History, Pending, or capture train.
- Do not read when: deciding current compact Pending, Latest, or text-only History.
- Maximum size: 100 physical lines.

This source described local accepted/failed History, PendingRecording, retry
audio, recording cache, and protected capture ownership. Its generation,
outbox, cache, and five-failed-row model do not drive current implementation.

## Children

- [History policy and presentation](ios-history-and-storage/history-policy-and-presentation.md)
  — generations, rows, actions, UI states, disclosure, and concurrency.
- [Pending recording](ios-history-and-storage/pending-recording.md) — strict
  journal/audio identity, phases, durability, and explicit recovery.
- [Dispatch and app-only acceptance](ios-history-and-storage/dispatch-and-acceptance.md)
  — one-shot provider authority, cancellation, P4 output, and relaunch.
- [Capture source](ios-history-and-storage/capture-source.md) — P4D namespace,
  manifests, finalization, recovery, and recorder qualification.
- [Capture transfer and relaunch](ios-history-and-storage/capture-transfer.md) —
  descriptor-bound Pending handoff, crash windows, discard, and scavenging.
- [Ownership and retention](ios-history-and-storage/ownership-and-retention.md) —
  staged destinations, History/cache separation, cleanup, and invariants.
- [Verification](ios-history-and-storage/verification.md) — failure policy,
  routes, evidence, and historical release gates.

## Precedence

- [Current V1.1 release](ios-v1-release.md), [Voice state](ios-v1-voice-state-persistence.md),
  and [Voice audio](ios-voice-session-and-audio.md) govern current behavior.
