# Historical Accepted Delivery Ordering And History

- Node type: leaf
- Status: Historical
- Read when: tracing retired P4/P5H durability and History ownership.
- Do not read when: activating History coupling in current V1.1.
- Maximum size: 100 physical lines.

P4 ordered exact Pending ownership, generation-0/history-null delivery commit
or atomic replacement, destination revalidation, protected Pending audio and
journal retirement with durable absence, then resultReady. Failure stayed at
Saving Result and retried only the missing local checkpoint; provider work was
never repeated. No destination allowed explicit provider-free recovery, but a
durable destination could not fall back to provider Retry.

P5 ordered delivery with unresolved History marker, idempotent row decision,
terminal marker CAS, generation-1 commit, bounded bridge publication, then
Pending retirement. History failure retained structured local retry and did not
block otherwise durable output or repeat transcription.

Transfer and bridge reservations were opaque, store/owner/snapshot/deadline-
bound, mutually exclusive, one-use capabilities. They froze the authorized
snapshot and could not be replaced by caller assertions. History policy was a
strict app-private revision/generation record; cutover committed generation
before cleanup and could not change accepted text, delivery, publication,
Latest, or bridge eligibility.

A strict bounded FIFO outbox owned unresolved payload before replacement,
clear, discard, or non-retention. It never evicted a live retry. Terminal marker
removal required a paired-store, leased exact outbox-absence capability; expiry
was the bounded abandonment exception. No failed/uncertain mandatory commit
authorized History, bridge, cleanup, or provider replay.
