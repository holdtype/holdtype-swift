# Deferred Accepted History Outbox Worker

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing the retired transfer and one-head recovery protocol.
- Do not read when: treating it as a current V1.1 worker.
- Maximum size: 100 physical lines.

Pending delivery removal first transferred exact reconstructible payload to
outbox. A delivery-store reservation was owner/store/snapshot/generation/deadline-
bound, claimed once by the paired outbox, and superseded the policy receipt.
Transfer and bridge-publication reservations were mutually exclusive and froze
the delivery snapshot; neither performed publication itself.

Replacement consumed the claimed reservation plus exact membership receipt.
Uncertainty retained exact preparation, authorization, reservation, receipt,
and revisions. Relaunch reauthorized old delivery and confirmed duplicate
membership; pendingReplacement reconstructed only its row-decision authority.
Expiry was bounded abandonment and never created another outbox entry.

One provider-free call processed only the store-selected canonical oldest head.
It confirmed membership, classified one clock sample, confirmed policy, decided
the row if eligible, reconciled exact delivery marker, then revision-CAS retired
that head. Failure, rollback, uncertainty, conflict, or supersession never
skipped to another entry; a later call selected the next.

Terminal delivery removal while matching membership existed required an opaque
paired-store absence capability valid only inside the issuing root-gate lease.
It was consumed immediately and invalidated before lease release. Stale/cross-
root/store/gate capabilities were no authority. The guard preserved a sealed
not-retained decision until FIFO retirement; exact delivery expiry was the only
bounded abandonment exception.
