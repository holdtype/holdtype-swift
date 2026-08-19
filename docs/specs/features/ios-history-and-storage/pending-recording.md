# Historical iOS Pending Recording

- Node type: leaf
- Status: Historical
- Read when: reviewing the retired strict PendingRecording foundation.
- Do not read when: selecting current V1.1 Pending repository behavior.
- Maximum size: 100 physical lines.

One app-private protected audio file plus one strict journal committed before
provider work. Canonical attempt UUID, relative audio identifier, timestamps,
phase, intent, optional transcription UUID, model/language, duration, and byte
count formed an exact bounded v1 wire shape. Absolute URLs, App Group, secrets,
prompts, payloads, context, and raw runtime-enum encoding were forbidden.

Durable phases were readyForTranscription, awaitingRecovery, transcribing,
postProcessing, and outputDelivery with exact ID invariants and forward-only
transitions. Process loss never resumed provider work; it required proof of no
live owner and durable absence/mismatch classification before presenting
explicit Retry or Discard. Stale callbacks could not mutate another owner.

Protected audio used owner-only no-follow single-link files, Complete Data
Protection, backup exclusion, exact marker, bounded streaming, stable identity,
strict container/duration checks, and no-overwrite publication. Journal commit
uncertainty preserved visible bytes but returned no provider authority until an
identical rewrite and directory sync confirmed them.

Discard removed exact audio before journal and required durable absence of
both; missing metadata never authorized filename-based deletion. Corrupt,
future, substituted, locked, missing-linked, or ambiguous state was preserved
as local recovery. One unresolved attempt blocked another chain.
