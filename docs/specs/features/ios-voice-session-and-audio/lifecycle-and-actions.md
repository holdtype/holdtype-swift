# iOS Voice Lifecycle And Actions

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.actions@1`
- Read when: foreground loss, recovery presentation, or exact action semantics matters.
- Do not read when: only normal preflight matters.
- Maximum size: 100 physical lines.

P4 is foreground-only/no Quick Session. One scene loss is safe if another active.
Last-active loss: permission-sheet arming waits for initiator; other arming cancels
all/no capture/provider; listening/tail stops and protects bounded non-empty
without auto-upload (source Recover/Discard, journal Retry/Discard, unknown
duration preserved, empty Discard-only, uncertainty blocked); stopped finalization
may only protect locally; journaled processing deactivates audio and may finish
as iOS permits, otherwise explicit recovery/no replay. Foreground reconciliation
selects exact source/Pending actions and never starts work. Route/mute/media/mic
revocation uses same policy; output-only exact proof may continue; reset waits Start.

Actions are distinct: Done applies tail, finalizes/journals/provider; Cancel
Utterance destroys only explicitly invoked unfinished artifact; teardown/task/
scene/bridge/supersession preserves possibly non-empty. Cancel Processing only
after durable provider identity: before transcription preserves Retry/Discard,
after dispatch unknown hides Retry and keeps Play/Discard; rejects late results.
Historical Stop Voice Session is not P4 behavior.

Matrix: inactive Start (Translate invalid routes Settings); arming progress+Cancel
Start; listening Done+Cancel, tail ignores Done; finalizing noninteractive;
processing current stage+Cancel after durable dispatch. Accepted text with local
commit/cleanup shows Saving Result + Retry Saving, never provider replay. Latest
replacement is atomic/fail-closed. Valid source has Recover+confirmed Discard;
resumable preparation may Recover only; exact zero active Discard-only (automatic
cleanup only bounded one-hour rule); matching journal with absent final Recover
only. Pending Retry+Discard blocks Start. Result appears via Draft/History, no
Latest card/actions. Every action at-most-once by phase/identity.
