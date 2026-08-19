# iOS Keyboard Shared State

- Node type: hybrid
- Status: Historical legacy Phase 0
- Read when: reviewing early App Group snapshot/Quick Session bridge evidence.
- Do not read when: defining current command, handoff, Latest, or delivery state.
- Maximum size: 100 physical lines.

Current V1.1 supersedes historical listening/transcribing/command/ack/automatic
delivery. Phase 0 app was single writer; extension read on appearance/context.
Snapshot was not event bus/wake mechanism and static preferences were separate.

## Children

- [Phase-0 snapshot](ios-keyboard-shared-state/phase-zero.md) — schema, validation,
  ownership, failures, and forbidden data.
- [Future bridge evidence](ios-keyboard-shared-state/future-bridge.md) — historical
  directional writers, heartbeat, expiry, and cleanup model.

## Precedence

- [Current V1.1 release](ios-v1-release.md) and [canonical handoff](ios-keyboard-handoff-and-delivery.md) govern.
