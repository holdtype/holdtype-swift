# Deferred Failed History Record And Transfer

- Node type: leaf
- Status: Historical; Deferred
- Read when: reviewing the proposed failed-root and Pending transfer protocol.
- Do not read when: defining current Pending storage.
- Maximum size: 100 physical lines.

One strict protected backup-excluded app-private failed-history v1 record held
revision, at most five entries, and at most five audioCleanup tombstones. Rows
used exact canonical identities/times/generation/category/stage/count/intent/
model/language/duration/bytes/relative-audio plus ownership and nullable retry
operation. Malformed/future/unavailable/protection-invalid data was preserved.

Ownership was pendingJournalRetirement or ready; at most one transfer row could
exist. Tombstones contained only exact attempt/generation/time/audio ID/bytes,
were oldest-first, and alone authorized later physical removal. Attempt/audio
identity was unique across rows and tombstones; no automatic legacy import.

Provider-free transfer validated exact awaitingRecovery Pending journal/audio,
enabled policy, root/store/lease identities, and sealed full snapshot plus
descriptor lease. It committed the row first, then a store-minted receipt
removed only Pending metadata, proved durable absence, and advanced that row to
ready without changing its visible failure time. Audio never moved or copied.

Crash recovery used complete shared-field identity, strict journal phase/null
transcription ID, fresh root-bound directives and absence receipts. A mismatch,
capacity/full cleanup, stale policy, live provider, foreign root, or uncertainty
left Pending canonical. Failed-row/tombstone/Pending inventory was sealed and
bounded; duplicate/unknown/staging/missing files failed closed.
