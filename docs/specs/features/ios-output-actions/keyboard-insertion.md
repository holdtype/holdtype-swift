# Historical iOS Keyboard Insertion

- Node type: leaf
- Status: Historical
- Read when: reviewing retired automatic/manual insertion safety evidence.
- Do not read when: implementing current handoff or explicit Latest insertion.
- Maximum size: 100 physical lines.

Insertion required a visibly active HoldType keyboard and editable host field.
Automatic insertion additionally required the acknowledged Full Access gate,
app authorization, supported unexpired projection, matching delivery/session/
attempt/transcript/generation, matching non-empty document identity, and no
existing durable claim. A document identifier was only a conservative guard,
never proof of app, field, cursor, or intent.

Explicit Insert targeted the visible field at tap time. Before `insertText`, a
bounded protected extension ledger atomically claimed the delivery ID. It held
no text/host identity, retained at most 512 live IDs for 24 hours, and failed
closed instead of evicting a live duplicate barrier. An interrupted `claimed`
state never replayed automatically.

Because `insertText` returns no success, `confirmedInserted` required the same
document identity and an immediate in-memory suffix match. Otherwise the honest
terminal result was `submittedUnverified`, with recovery and no replay. Text over
8,192 UTF-8 bytes stayed app-private and was never chunk-inserted. Bidirectional
text remained isolated plain text.

Undo existed only for confirmed insertion while the same target still ended in
the exact submitted text. Missing durable ledger state disabled insertion;
without Full Access only separately proven read-only/manual behavior could run.
