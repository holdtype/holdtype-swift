# iOS Voice Production Composition

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.composition@1`
- Read when: process owners, scenes, launch recovery, or credential authority matters.
- Do not read when: only audio configuration matters.
- Maximum size: 100 physical lines.

Construct one process Voice workflow/controller, permission/session/feedback/
finalization owners and recorder factory; share across scenes even when secure
credential unavailable so observation/Recover/Discard work. One scene registry;
initiator alone owns prompts. If it disappears, reject late completion/no audio.
Start follows preflight sequentially and revalidates after permission and cue.
Only expected permission-sheet inactivity is tolerated; other last-scene loss
idempotently stops and rejects callbacks, never auto-resumes.

Launch recovery is provider-free: bounded orphan repair, source reconciliation,
existing lifecycle recovery, combined source/Pending before Start. Descriptor
validator max 2 s; bounded non-empty becomes completed, uncertain duration `0`
with Play/Transcribe/Discard/no auto-provider; empty Discard-only without delete;
protection/write uncertainty blocked. Foreground never orphan-repairs. One
conditional second source read only after blocked first and successful lifecycle,
unless repair blocked; second blocked ends with no loop. No Keychain/permission/
audio/provider/bridge work.

Use process History-playback arbitration (explicit no-active implementation until
UI), always stop/deactivate before recording. Credential bridge resolves only
voicePreflight, returns opaque generation-bound proof, never key/traversable owner.
Immediately before provider or authorized Retry resolve again; replacement/
removal/rejection/loss/access/mismatch/consumed proof fails before request.
Graph exists without coordinator; provider-free local Retry bypasses key/consent.
Bridge adds no network/retry/timeout.

Haptics always on; audible boundaries follow cue preference. After foreground
loss local finalization may protect; no new provider dispatch. Recovery declares
provider-free versus authority-required separately. Provider-required Retry uses
fresh consent+credential; provider-free checkpoints never read either or repeat
lost/completed provider work.
