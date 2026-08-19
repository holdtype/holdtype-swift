# Deferred Failed History Retention And Cutover

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing row/tombstone cleanup or generation cutover evidence.
- Do not read when: exposing Clear/Disable or failed retention in V1.1.
- Maximum size: 100 physical lines.

Logical removal atomically replaced one ready row with its exact cleanup
tombstone; cleanup then removed/confirmed only that protected file and retired
the tombstone. Each uncertainty retained its exact phase. No age scan, caller-
constructed path, bulk delete, or cross-owner deletion was allowed.

Admission of a sixth failure selected the absolute deterministic oldest row and
required it ready, idle, audio-valid, and one free tombstone slot. Otherwise the
new attempt remained visible as Pending. Ordinary lifecycle processed only the
canonical tombstone head; explicit Delete could drive only its own newly minted
tombstone and never skip unrelated work.

Confirmed policy generation immediately filtered old failed rows. Cutover first
finished exact retained failed work, reconciled one transfer, locally cancelled
one process-lost reserved/dispatched Retry, cleaned one head, or tombstoned one
oldest invalidated ready row. One call performed at most one failed-domain
action, then returned pending; retries never advanced policy again.

AcceptingOutput was never generic stale work and required its exact delivery
relation. Future/corrupt/unavailable/rollback/foreign state stayed preserved.
One root-shared retry owner survived its minting lease and blocked conflicting
policy/delete/audio/Pending provider work; only a new idle process context plus
durable operation proved process loss.
