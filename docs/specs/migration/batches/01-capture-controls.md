# Batch 01 — Capture Controls

- Node type: leaf
- Status: complete
- Batch ID: `01-capture-controls`
- Change mode: Reconcile
- Source documents: 3
- Source words: 4816
- Read when: batch 01 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 01 is accepted.
- Maximum size: 100 physical lines.

## Sources and baseline hashes

- [Microphone input](../../features/microphone-text-input.md) — `6b53d6f060c92e47f0957559739ef1c662966d1634f3bc6a4ec9e26c2ff1d85c`.
- [Global hotkey](../../features/global-hotkey.md) — `a98b39bbce33a4580ee5a02e43d113167565953fcd374a8bca528a9efa08afd7`.
- [Floating indicator](../../features/floating-indicator.md) — `c9ce692af387d566fd08c5c8b7749c4ec5edd9d41b4b7bc43f66545b9cdafa44`.

## Dispositions

- Microphone input: `contract` — retained as a hybrid with four responsibility leaves.
- Global hotkey: `contract` — retained as a hybrid with three action/registration leaves.
- Floating indicator: `contract` — retained as a hybrid with presentation and lifecycle leaves.

## Protected meaning

- Device identity, permission, duration, warning, exact-once, artifact,
  recovery, lease, and cache boundaries remain unchanged.
- Right Command, Translation, Fixes, Paste Last Result, registration fallback,
  and permission behavior remain unchanged.
- Indicator countdown, visual state, non-activation, ownership, and recovery
  ordering remain unchanged.
- Linked recording, output, Settings, Fixes, Dev Vlogs, and History contracts
  remain independent and unmodified.

## Acceptance

- All three sources retain their inbound paths and one visible disposition.
- Every created node is reachable and at most 100 physical lines.
- Coverage against pinned source revision `fe092f2c` reaches 6 of 54 sources
  with no duplicate or unknown disposition.
- No product implementation, behavior, precedence, release scope, or JSON
  routing state changes.

## Next

After the scoped checkpoint is pushed, activate batch `02-recording-history`.
