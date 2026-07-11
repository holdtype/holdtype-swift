# iOS Failed History Contract QA

Date: 2026-07-11
Checkpoint: P2 C4.0 failed History and retry-audio contract

## Scope

- Freeze the bounded failed-row, retry-only audio, retention, Delete, policy
  cutover, and explicit Retry behavior before implementation.
- Reconcile the contract with the completed `PendingRecording`, accepted-output,
  accepted-History outbox, and C3 policy-cutover boundaries.
- Keep user-visible History controls deferred until failed rows and audio
  cleanup are implemented and verified.

## Evidence

- Reviewed current `IOSPendingRecording` value/store/audio namespace,
  `IOSAcceptedHistoryCoordinator`, `IOSHistoryPolicyCutover`, accepted-output
  acceptance, and their focused tests before freezing the target contract.
- Cross-checked the general History behavior in
  `docs/specs/features/ios-history-and-storage.md` and the active roadmap and
  keyboard gates.
- Reviewed product consistency, crash/ownership architecture, and Apple
  privacy/extension isolation as separate risk axes.
- `git diff --check`
  - Result: passed for all C4.0-owned documentation.

## Contract Decisions

- Five visible failed rows and five exact audio-cleanup tombstones are the
  bounded v1 limits.
- Failed rows keep the already protected attempt audio at its current stable
  pending-recording path; durable ownership changes before old metadata is
  retired.
- Capacity never silently drops a new or old attempt. Without safe cleanup
  ownership, the new failure remains under `PendingRecording` recovery.
- Relaunch recovery is provider-free. Explicit Retry uses fresh setup, one
  cancellable handoff, automatic insertion off, and normal accepted-output
  durability before failed-row cleanup.
- A durable Retry success protects its exact accepted-output delivery from
  replacement, clear, expiry, or bridge mutation until the failed row is
  retired, so process loss cannot erase the only success proof.
- A `pendingJournalRetirement` row remains physically durable through cutover
  until its row-bound authority removes and confirms the redundant pending
  journal; only a `ready` row may become an audio-cleanup tombstone.
- Clear and toggles keep the existing confirmed policy commit as the logical
  boundary and remain pending locally until invalidated failed rows and their
  exact audio tombstones are reconciled.
- No failed metadata, audio, provider input, secret, or cleanup authority enters
  App Group storage or the keyboard extension.

## Gate Decision

C4.0 specification gate: passed. C4.1 through C4.5 implementation and runtime
evidence remain required; this record does not claim failed History is shipping
or that any physical-device gate has passed.
