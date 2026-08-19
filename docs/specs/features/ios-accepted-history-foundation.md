# iOS Accepted History Foundation

- Node type: hybrid
- Status: Historical; Deferred as of 2026-07-13
- Read when: reviewing the retired transactional accepted-History foundation.
- Do not read when: deciding current V1.1 compact accepted-text History.
- Maximum size: 100 physical lines.

V1.1 replaces this app-private policy/accepted-row/outbox train. Do not continue
or activate it. The retained nodes preserve transactional and safety evidence.

## Children

- [Records and storage](ios-accepted-history-foundation/records-and-storage.md) —
  strict policy, accepted-row, outbox, JSON, protection, and retention.
- [Coordinator and acceptance](ios-accepted-history-foundation/coordinator-and-acceptance.md)
  — opaque receipts, replay boundary, ordering, uncertainty, and recovery.
- [Outbox worker](ios-accepted-history-foundation/outbox-worker.md) — transfer,
  replacement, one-head FIFO recovery, and terminal-proof protection.
- [Policy cutover](ios-accepted-history-foundation/policy-cutover.md) — deferred
  Clear/Disable/Enable generations and bounded stale cleanup.
- [Privacy and verification](ios-accepted-history-foundation/privacy-and-verification.md)
  — forbidden data, evidence, deferred owners, and non-activation.

## Precedence

- [Current V1.1 release](ios-v1-release.md) and [Voice state](ios-v1-voice-state-persistence.md)
  govern compact Pending, Latest, and accepted-text History.
