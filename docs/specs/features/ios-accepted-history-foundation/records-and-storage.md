# Deferred Accepted History Records And Storage

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing the retired policy/accepted/outbox wire contracts.
- Do not read when: defining current V1.1 compact History storage.
- Maximum size: 100 physical lines.

Three containing-app-only Application Support records owned strict policy,
accepted rows, and outbox membership. Owner-only no-follow regular files used
Complete protection, backup exclusion, exact markers, bounded I/O, file sync,
atomic publication, post-publication checks, directory sync, logical/physical
CAS, and identical rewrite after commit uncertainty.

Policy v1 had exact schema/revision/enabled/generation, with equal positive
counters. Missing became virtual 1/1 only after one coordinator proved accepted,
outbox, and delivery ownership empty; first authority physically confirmed 1/1.
Clear always advanced; state-changing enable/disable advanced; confirmed no-op
toggles did not. Overflow and uncertainty authorized no cleanup.

Accepted v1 held at most 20 newest exact-byte rows. Delivery/transcript identity,
text/intent/time/generation/model/language/duration were immutable; cache link
could move once null→value. Collision checks preceded stale pruning/insertion/
deterministic eviction. Duplicate or self-evicted candidate could confirm
durability without logical revision. Delete required no recreating delivery or
outbox owner.

Outbox v1 held at most 20 oldest-first reconstructible entries and never evicted
a live entry. Membership alone represented pending work. Exact duplicate was
idempotent; only expired or durably stale-generation entries could prune.
Strict JSON rejected malformed, unknown, duplicate, omitted-null, noncanonical,
oversized, or future bytes and preserved them without default/overwrite/cleanup.
