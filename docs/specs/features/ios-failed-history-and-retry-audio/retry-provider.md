# Deferred Failed History Retry Provider Work

- Node type: leaf
- Status: Historical; Deferred
- Read when: reviewing the proposed one-shot Retry state machine.
- Do not read when: implementing current Pending Retry.
- Maximum size: 100 physical lines.

Retry from a current ready row froze fresh setup, consent, credential,
transcription/prompt/correction/local/translation configuration and Keep Latest.
Its durable operation preallocated retry, transcription/Usage, delivery,
session, final-transcript IDs and state. Provider transcription ID and final
transcript ID were deliberately distinct.

Nil→reserved incremented count once and reserved cleanup capacity; reserved→
providerDispatched committed before one cancellable handoff. Provider ran
outside the root gate under a stable owner epoch; completion/cancel reacquired
the gate and only the exact epoch could mutate. Valid final requested text
moved to acceptingOutput; recoverable failure cleared operation and updated
category/stage, while cancel/unmapped outcome preserved prior category/stage.

Transcription/Translation timeouts were durable timedOut failures; Correction
failed open. Successful transcription recorded idempotent Usage, then one
frozen correction/local-processing pass; Translation consumed transient
processed text and only final translation was accepted. Usage failure could not
alter product outcome or replay provider work.

Process loss never resumed reserved/dispatched work. A required cold scan
classified strict failed state before other stores acted and locally cancelled
only exact operations under a new idle context. Rollback, corrupt/future/
unavailable/foreign/uncertain state kept the interlock closed. A release writing
retryOperation was no-downgrade to binaries lacking delivery protection.
