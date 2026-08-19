# iOS Failed History And Retry Audio

- Node type: hybrid
- Status: Historical; Deferred beyond V1.1 as of 2026-07-13
- Read when: reviewing the retired failed-row/retry-audio capability train.
- Do not read when: deciding current V1.1 Pending Retry/Discard behavior.
- Maximum size: 100 physical lines.

V1.1 excludes failed History, retry-audio ownership, its policy cutover, and
its UI. These nodes preserve the proposed durability and safety evidence only.

## Children

- [Product model and failure categories](ios-failed-history-and-retry-audio/product-model.md)
  — five-row behavior, user actions, eligibility, and stable failure mapping.
- [Record and Pending transfer](ios-failed-history-and-retry-audio/record-and-transfer.md)
  — strict failed root, ownership states, tombstones, and journal retirement.
- [Retention and policy cutover](ios-failed-history-and-retry-audio/retention-and-cutover.md)
  — deterministic cleanup, generations, provider-free recovery, and bounds.
- [Retry reservation and provider work](ios-failed-history-and-retry-audio/retry-provider.md)
  — frozen operation, owner epochs, stages, timeouts, and process loss.
- [Accepted-output interlock](ios-failed-history-and-retry-audio/accepted-output-interlock.md)
  — tagged delivery provenance, frozen predecessor, terminal History, success.
- [App boundary and lifecycle](ios-failed-history-and-retry-audio/app-boundary-and-lifecycle.md)
  — bounded DTO/actions, consent/setup, startup recovery, and scheduler.
- [Isolation and verification](ios-failed-history-and-retry-audio/isolation-and-verification.md)
  — coordination, privacy, invariants, evidence, and non-activation.

## Precedence

- [Current V1.1 release](ios-v1-release.md) and [Voice state](ios-v1-voice-state-persistence.md)
  govern the single Pending attempt and explicit Retry/Discard.
