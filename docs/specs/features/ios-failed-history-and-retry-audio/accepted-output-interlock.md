# Deferred Failed Retry Accepted-Output Interlock

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing exact Retry success and cross-store replay protection.
- Do not read when: treating failed-Retry provenance as current V1.1 behavior.
- Maximum size: 100 physical lines.

AcceptingOutput durably froze the delivery slot as missing or one fully observed
unrelated predecessor and installed a shared failed/delivery interlock before
gate release. Partial identity, substitution, corrupt/future/unavailable/
foreign/uncertain observation failed closed. Missing/unchanged predecessor after
relaunch proved no Retry delivery; exact matching tagged delivery proved success.

Only the Retry branch could consume store-minted permits and preallocated IDs,
intent, automatic-insertion-off, frozen Keep Latest, exact History metadata and
accepted bytes. Delivery v2 persisted required failedRetryID provenance; an
ordinary v1 record could not adopt the relation. Delivery commit was the replay
boundary and later local errors remained provider-free recovery.

The failed row remained until matching delivery History marker was committed or
cancelled by exact newer policy. The durable relation alone authorized one
absent-row History decision after process loss. PendingReplacement, missing
marker, discarded state, automatic insertion, or mismatched intent/preferences/
History data was a collision.

Only confirmed matching delivery plus terminal marker atomically removed the
row and appended its reserved tombstone. The live relation blocked replacement,
Clear, expiry removal, bridge/publication, and generic mutation. Expiry paused
only for proof-bound completion and never restored display/insertion. Failed-
store uncertainty preserved both proof stores; no caller IDs/assertions could
release the interlock.
