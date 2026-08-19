# iOS Accepted Output Delivery Record

- Node type: hybrid
- Status: Historical legacy delivery/recovery contract
- Read when: reviewing the retired History-coupled accepted-output train.
- Do not read when: deciding current V1.1 Pending, Latest, or text-only History.
- Maximum size: 100 physical lines.

This source specified a strict app-private crash-safe owner between accepted
text and History/keyboard/recovery completion. V1.1 replaces the capability
train; only safety invariants explicitly adopted by current contracts govern.

## Children

- [Identity and wire contract](ios-accepted-output-delivery-record/identity-and-wire.md)
  — IDs, revisions, states, strict schemas, text, dates, and History marker.
- [Storage and durability](ios-accepted-output-delivery-record/storage-and-durability.md)
  — protected repository, CAS, synchronization, uncertainty, and cleanup.
- [Ordering and History](ios-accepted-output-delivery-record/ordering-and-history.md)
  — P4/P5 ordering, reservations, policy, outbox, and provider-free retry.
- [Clear, replacement, expiry, and privacy](ios-accepted-output-delivery-record/lifecycle-and-privacy.md)
  — revocation, tombstones, atomic replacement, clocks, and extension isolation.
- [Verification and deferred work](ios-accepted-output-delivery-record/verification-and-deferred.md)
  — required evidence, device gates, compatibility, and non-activation.

## Precedence

- [Current V1.1 release](ios-v1-release.md), [Voice state](ios-v1-voice-state-persistence.md),
  and [keyboard handoff](ios-keyboard-handoff-and-delivery.md) govern.
