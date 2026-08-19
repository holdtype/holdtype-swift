# Deferred Accepted History Coordinator And Acceptance

- Node type: leaf
- Status: Historical; Deferred
- Read when: reviewing the retired receipt/capability acceptance boundary.
- Do not read when: implementing current compact History acceptance.
- Maximum size: 100 physical lines.

One root-bound process coordinator serialized policy, accepted, outbox, and
delivery through a FIFO non-reentrant gate. Opaque non-Codable receipts carried
exact owner, identity, generation, logical/physical revision, and decision.
Cross-root/store capabilities, mixed owner graphs, aliases that changed binding,
Booleans, stale revisions, and caller assertions failed before repository work.

Only an opaque enabled policy capture could create a pending History marker.
Normal acceptance confirmed delivery durability, validated generation, made an
idempotent row decision, revalidated policy, then committed the terminal marker.
Delivery acceptance was the provider-replay boundary: later local failure
returned pendingLocalRecovery and never repeated provider work.

Fresh-commit provenance survived uncertainty. A preexisting ordinary pending
delivery could confirm present membership but never insert an absent row after
relaunch. Store-minted pendingReplacement was the narrow replayable exception;
capacity rejection used an identical source rewrite and became durable only
when the exact terminal delivery marker sealed it.

Retained phases kept exact owner-bound capabilities and blocked different work.
Recovery strictly reloaded and identically confirmed records; pending moved to
committed only with row proof and cancelled only with newer-policy proof.
Expiry/rollback/commit uncertainty retained their sealed local phase without
resampling or recreating authority.
