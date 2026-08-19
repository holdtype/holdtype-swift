# iOS V1.1 Keyboard Latest Projection

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.keyboard-latest@1`
- Read when: the keyboard's explicit `Latest` action or shared snapshot matters.
- Do not read when: automatic same-request insertion alone matters.
- Maximum size: 100 physical lines.

- App publishes one replaceable History-latest snapshot to App Group; extension
  may read/insert it when restricted-mode access permits.
- This is a one-writer cache, not History or a delivery transaction: no outbox,
  receipt, acknowledgement, tombstone, or replay.
- Current-schema snapshot has schema version, revision, and at most the first
  canonical accepted-History item: result ID, exact text, creation time. It has
  no other row, secret, audio, prompt, dictionary, provider response, setting,
  or host context.
- No independent age/expiry. `Latest` remains while canonical History has an
  insertable first row. Deletion republishes next; Clear All or History-off
  publishes empty. Load/projection failure replaces old shared text with empty
  current schema; rebuild legacy schemas from History on app startup.
- `Latest` inserts only valid projected first item and never previews text.
  Full History, Delete, Clear All, playback, and retention stay in app.
- Extension requests no external Settings/app launch; setup recovery remains
  readable without system callback.
- Each `Latest` tap is explicit and calls `textDocumentProxy` once with
  re-entrancy suppressed. The same valid result may insert again only after a
  new tap. Relaunch, refresh, host change, or app return never auto-replays; no
  durable consumed-ID log is needed.
- Invalid/unavailable snapshot disables `Latest` while punctuation, editing,
  Globe, and Ready remain. Secure fields, phone pads, and host opt-out use
  system behavior; HoldType never bypasses policy.
