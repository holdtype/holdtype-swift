# Historical Phase-0 Shared Snapshot

- Node type: leaf
- Status: Historical
- Read when: reviewing Phase-0 snapshot compatibility evidence.
- Do not read when: implementing current App Group records.
- Maximum size: 100 physical lines.

Schema v1 contained revision; optional session; idle/listening/transcribing/
transcriptReady/failed; optional source document ID; timestamps/expiry; optional
accepted ID/trimmed nonempty text/date; optional automaticInsertionAuthorized
default false after preference gate. It forbade audio/key/prompts/keystrokes/
context/host/provider/analytics.

Insertion required supported unexpired transcriptReady with text. Bad data was
unavailable, writes replaced whole file, app owned short expiry. Missing container
was setup unavailable; missing/expired no transcript; decode error redacted;
write failure retained prior snapshot. Extension received no secrets/audio,
snapshot no context, logs no text, Phase 0 needed no Full Access/write, shared
state never implied app running.
