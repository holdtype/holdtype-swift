# Historical Accepted Delivery Identity And Wire Contract

- Node type: leaf
- Status: Historical
- Read when: tracing the retired strict delivery schemas and state machine.
- Do not read when: selecting current V1.1 repository schemas.
- Maximum size: 100 physical lines.

One accepted attempt/transcript received a fresh delivery UUID; session,
attempt, transcript, and delivery identities were immutable and byte-exact.
Record revision advanced once per logical mutation. Publication generation was
separate and only 0 or 1: first authorized publication committed 1, refresh kept
it, and revocation permanently ended that delivery epoch.

States were pending, confirmedInserted, submittedUnverified, or discarded.
Only pending could reach an insertion result; non-discarded could tombstone;
terminal states never returned to pending. Impossible cross-field combinations,
stale terminal callbacks, overflow, unknown members, and unsupported versions
failed closed.

Version 1 had an exact 16-field JSON shape. Version 2 added the mandatory
store-minted failedRetryID only for failed-Retry acceptance. Older readers
preserved unsupported bytes. Tagged records and pendingReplacement introduced
explicit no-downgrade boundaries until retired.

Accepted text used a frozen edge-whitespace trim set, rejected forbidden
controls/empty/over-131072 UTF-8 bytes, and preserved exact UTF-8 without later
normalization. Dates were strict UTC milliseconds; expiry was createdAt plus
86400 seconds. HistoryWrite was null or exact structured policy/model/language/
duration state, with unresolved pending/pendingReplacement moving only to
committed/cancelled. Callers could not forge replacement or Retry provenance.
