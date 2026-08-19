# Historical Output History Coupling And Verification

- Node type: leaf
- Status: Historical
- Read when: reviewing the retired P4/P5H output capability train.
- Do not read when: activating History coupling or current release behavior.
- Maximum size: 100 physical lines.

P4 was app-only: one mandatory generation-0 pending record, no App Group,
insertion, acknowledgement, or History. ResultReady followed confirmed delivery
and Pending audio/journal retirement. Clear and replacement were fail-closed,
provider-free, atomic, and could not reconstruct a tombstone or erase the only
accepted payload.

The frozen P5H train captured History policy/generation at acceptance, embedded
structured pending row metadata, attempted the row before publication, retained
local outbox work on failure, and never repeated provider work. P4 results were
not backfilled. Policy cutover affected only History ownership, not accepted
text, delivery/publication, bridge eligibility, or explicit recovery actions.

Historical states distinguished pending, eligible, explicit-action-required,
confirmed, submitted-unverified, recoverable pre-attempt failure, and expired.
Setup failures routed to their actual owner. Delivery adapter stage did not
become a second global state model or a failed transcription row.

Evidence obligations covered normalization, eligibility/identity/expiry,
duplicate suppression, suffix confirmation, corrupt/delayed bridge state,
relaunch and eviction, app actions, secure/phone fields, host rejection,
Full Access changes, automatic/manual Insert, and Undo. M0B/M0C and production
bridge/device gates were mandatory and never activated by this migration.
