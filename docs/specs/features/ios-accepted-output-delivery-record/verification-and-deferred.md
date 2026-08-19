# Historical Accepted Delivery Verification And Deferred Work

- Node type: leaf
- Status: Historical
- Read when: tracing evidence obligations of the retired delivery train.
- Do not read when: claiming current release acceptance from legacy evidence.
- Maximum size: 100 physical lines.

Deterministic evidence covered strict codecs/bounds/UTF-8, state transitions,
identity collisions, CAS and competing actors, clocks/expiry, History marker and
replacement uncertainty, reservations/outbox FIFO/terminal proof, atomic
replacement, durable absence, opaque tombstones, process-relaunch confirmation,
corrupt/future discard, staging limits, file protection/mode/link/substitution,
partial I/O, sync/rename uncertainty, ordering authorization, and redaction.

Writers of pendingReplacement or version-2 failed-Retry provenance required
no-downgrade release evidence, backward version-1 decode, strict round trip,
allowlisting, and preservation by older binaries. The 24-hour lifetime did not
make an unreadable downgrade safe.

Deferred owners still required policy-cutover cleanup, failed History, retry
audio, Recording Cache, App Group bridge, claim ledger, acknowledgement channel,
and UI evidence. Unit/fault tests owned codec/state/CAS/clocks/syscalls; Simulator
owned file metadata/App Group/target linkage; physical devices owned Data
Protection, Full Access, hosts, document proxy, directory sync, and locking.
Power loss, deterministic eviction, and real backups remained lab/manual gates.

This migration activates none of those components or gates. Current release
contracts decide which safety invariants survive.
