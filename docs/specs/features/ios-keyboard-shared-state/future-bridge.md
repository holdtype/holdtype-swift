# Historical Future Bridge Evidence

- Node type: leaf
- Status: Historical
- Read when: tracing retired Quick Session bridge design.
- Do not read when: treating it as current transport authority.
- Maximum size: 100 physical lines.

Exploration split app snapshot from extension commands/acks/heartbeat with one
writer/revision each, no cross-writer RMW. It proposed owner-bound reservations,
delivery generation, phase-valid commands, and no caller assertion authority.
These transactional concepts are superseded by current bounded handoff.

Heartbeat held schema/revision/generated/expiry/presented/fullAccess true, TTL
five minutes, no content. Fresh meant recently verified; absent/expired meant
not currently verified, never disabled. Writers cleaned only own envelopes/temp
on lifecycle; readers never delete foreign mutable paths. All transient files
Complete-protected/backup-excluded; logical TTL always blocked use though physical
cleanup could wait. Full Access required updated disclosure and never granted mic.
Document identity was conservative guard, not host/cursor proof.
