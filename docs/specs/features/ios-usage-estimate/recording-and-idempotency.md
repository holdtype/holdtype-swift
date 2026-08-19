# iOS Usage Recording And Idempotency

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.ios.transcription-usage-estimate@1`
- Clauses: `IOS-USAGE.RECORD`, `IOS-USAGE.HANDOFF`
- Read when: iOS audio provider acceptance or retry may produce a usage event.
- Do not read when: only Usage UI or repository decoding is in scope.
- Maximum size: 100 physical lines.

- Immediately after accepting a non-empty provider transcript and before
  correction/translation/History/output, containing app hands off one event.
  Later failure/cancellation does not revoke it.
- Successful explicit Retry with valid duration creates one new event; failed/
  pre-accept cancellation none. Legacy success with bad/missing duration keeps
  text but invents no event.
- Before every actual audio request allocate local transcription UUID; callback
  replay reuses it, new request/retry gets new. Correction/translation/output retries do not.
- Pending-attempt journal durably stores UUID before a replayable request.
- Runtime-only Equatable/Sendable/non-Codable handoff contains only UUID,
  trimmed/lowercased non-empty model, and positive finite duration. It has no
  time, price, persistence, content, provider/session/document/account identity,
  keyboard, or App Group meaning.
- Repository uses UUID as event ID, adds timestamp/frozen local price, and
  treats retained repeat as idempotent no-op.
- Event contains only ID, timestamp, normalized model, duration, optional known
  USD/minute and cost, and optional pricing source/version. Frozen rate never changes.
