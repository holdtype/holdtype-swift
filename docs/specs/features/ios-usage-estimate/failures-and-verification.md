# iOS Usage Failures And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.ios.transcription-usage-estimate@1`
- Clauses: `IOS-USAGE.FAILURE`, `IOS-USAGE.PRIVACY`, `IOS-USAGE.VERIFY`
- Read when: usage errors, privacy, concurrency, release qualification, or acceptance is in scope.
- Do not read when: only happy-path recording is in scope.
- Maximum size: 100 physical lines.

- Unsupported/corrupt storage is recoverable and preserved, never overwritten.
  Append failure leaves dictation/output available. Cancelled refresh is not an
  error and late completion is ignored; competing scenes cannot admit commands.
- Over-4-MiB source rejects before decode. Append that would exceed limit fails
  without modifying/evicting valid retained events. Reset/compaction failure
  preserves source. Public error reveals no path/value/content/key/audio/payload.
- Time-zone changes regroup presentation without rewriting/duplicating events.
  Pricing updates affect only new events absent an explicit migration.
- Usage never enters backup, App Group, keyboard, Keychain, logs, diagnostics,
  exports, or live provider billing/usage calls.
- Verify exact-once/retry/exclusions; summaries/time zones/pricing; same actor
  across Voice/Retry/UI and concurrent writes; 365-day pruning/strict decode/
  corruption/atomic failures/reset; refresh cancellation/operation suppression/
  fence notices; compact-iPhone/iPad maximum-Dynamic-Type UI and accessible chart.
- Release verifier rejects usage qualification fixture in app bundle and any
  repository/estimate/filename/qualification markers in keyboard bundle.
- Correction/translation token estimates remain an explicit future contract.
