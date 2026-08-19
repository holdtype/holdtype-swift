# Historical Accepted Delivery Storage And Durability

- Node type: leaf
- Status: Historical
- Read when: reviewing retired protected-file and uncertainty safeguards.
- Do not read when: inferring the current repository location or schema.
- Maximum size: 100 physical lines.

The sole app-owned record was Application Support/HoldType/
ios-accepted-output-delivery.json, never App Group, defaults, clipboard,
restoration, widgets, Spotlight, or diagnostics. Owner-only directory/file
modes, regular one-link files, no-follow opens, Data Protection Complete,
backup exclusion, and an exact xattr marker were verified before content.

Commit used bounded descriptor-relative read, strict decode, revision/file-
revision CAS, protected staging, complete write/fsync, identity revalidation,
atomic rename, post-rename metadata validation, and directory fsync. Pre-rename
failure kept old bytes. Post-rename failure was commitUncertain and required an
identical reread/rewrite confirmation before any side effect.

Canonical absence also required pinned root/path identity plus directory
durability, not ENOENT alone. Process-local uncertainty blocked load/mutation/
authorization until exact intent reconciled. One static mutex plus directory
flock serialized actors; stale snapshots, callbacks, clear, acknowledgement,
and retries could not overwrite newer state.

First side-effect authorization in each process identically rewrote and synced
the valid record. Corrupt/future bytes stayed preserved unless explicit opaque
discard first proved bridge revocation and exact file revision. Bounded staging
cleanup recognized only exact old temporary names, never links/substitutions or
unknown siblings, and synced the directory after removal.
