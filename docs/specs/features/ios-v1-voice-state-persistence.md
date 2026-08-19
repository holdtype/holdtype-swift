# iOS V1.1 Voice State Persistence

- Node type: hybrid
- Status: Active
- Stability: Accepted
- Contract: `holdtype.ios.voice-state@1`
- Approved: 2026-07-13
- Read when: V1.1 Pending, Latest, replay safety, or process-loss recovery matters.
- Do not read when: historical transactional iOS persistence is requested as evidence.
- Maximum size: 100 physical lines.

This is the V1.1 replacement for legacy transactional Pending, accepted-output
delivery, accepted/failed History, and retry-audio contracts. Compact successful
History remains a separate release repository/screen.

## Goal

Preserve one unfinished foreground dictation and one accepted result across
process loss without replaying remote work or retaining multi-record transactions.

## Children

- [Durable state](ios-v1-voice-state-persistence/durable-state.md) — one Pending,
  one Latest, stage checkpoints, frozen recording boundary, retention ownership.
- [Flow and cleanup](ios-v1-voice-state-persistence/flow-and-cleanup.md) — capture,
  Retry/Discard, Latest→History order, and protected publication.
- [Relaunch](ios-v1-voice-state-persistence/relaunch.md) — orphan repair,
  replay blocks, stage-specific resume, and corruption handling.
- [Storage and verification](ios-v1-voice-state-persistence/storage-and-verification.md)
  — privacy, ignored legacy data, and focused acceptance matrix.

## Dependency

- [V1.1 release](ios-v1-release.md) — canonical scope, History, projection,
  Recording Cache, and signed-device gate.
