# Transcript History and Recording Recovery

- Node type: hybrid
- Contract ID: `holdtype.macos.transcript-history`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.transcript-history@1`
- Read when: accepted transcript persistence, saved-recording recovery, History UI, retry, or local deletion is in scope.
- Do not read when: only capture ownership, provider HTTP, or normal recording cache is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

HoldType keeps recent accepted dictations recoverable across relaunch and
protects completed recordings when provider or lifecycle work fails. Accepted
history and unfinished-audio safety checkpoints are distinct local stores.

This domain covers accepted transcript retention, saved attempts, recovery
actions, History presentation, local playback, system-clipboard copy, exact-row
deletion and clear, privacy, dispatch seals, repair, and relaunch reconstruction.

## Non-goals

- Unbounded archives, cloud sync, accounts, sharing, telemetry, full search,
  semantic notes, tags, folders, review workflows, or a required database.
- Durable raw audio outside unfinished recovery, successful maximum-duration
  recovery, or explicitly enabled normal recording cache.

## Children

- [Accepted-history policy](transcript-history/accepted-history-policy.md) — default, toggle, retention, accepted append, and Last Transcript boundaries.
- [Saved-recording lifecycle](transcript-history/saved-recording-lifecycle.md) — recovery creation, validation, maximum-duration identity, and retention.
- [Dispatch seals and retry](transcript-history/dispatch-seals-and-retry.md) — fail-closed provider authority, uncertainty, retry, and raw-text recovery.
- [Recovery state model](transcript-history/recovery-state-model.md) — visible row states, actions, playback, concurrency, and terminal transitions.
- [History window and deletion](transcript-history/history-window-and-deletion.md) — ordering, copy, cache playback, row Delete, and Clear History.
- [Data and privacy](transcript-history/data-and-privacy.md) — allowed fields, local-only storage, and logging limits.
- [Repair and relaunch](transcript-history/repair-and-relaunch.md) — persistence failures, orphan reconstruction, edge cases, and verification.

## Shared invariants

- Explicit Discard/Delete is the only authority to remove unresolved positive-byte recovery audio.
- Provider work starts only after durable audio ownership and a dispatch seal.
- Accepted and recovery stores remain local, bounded, and independent of Last
  Transcript, Last Result, normal cache, Keychain, and current app output.
- A row never claims Play, Retry, saved text, or deletion success unless its
  exact underlying state makes that action truthful.

## Dependencies

- [Recording durability](recording-durability-and-interruption.md) — terminal causes and ownership.
- [OpenAI transcription](openai-transcription.md) — provider attempt classification.
- [Text output](text-output-workflow.md) — Last Transcript and Last Result.
- [Settings and secrets](settings-and-secret-storage.md) — history and cache settings.

Capture completion and recovery-copy production remain owned by
`microphone-text-input.md`; History consumes that output without a reverse
dependency on the capture contract.
