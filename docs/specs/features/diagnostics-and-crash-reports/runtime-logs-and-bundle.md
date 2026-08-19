# Runtime Logs And Diagnostic Bundle

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.diagnostics-and-crash-reports@1`
- Clauses: `DIAGNOSTICS.LOGS`, `DIAGNOSTICS.BUNDLE`, `DIAGNOSTICS.VERIFY`
- Read when: runtime-event logging, retention, bundle export, redaction, or diagnostics verification is in scope.
- Do not read when: only system crash-report discovery is in scope.
- Maximum size: 100 physical lines.

- Recent Runtime Events may show/copy/reveal app-owned cache logs. Use unified
  HoldType subsystem/narrow categories plus readable text lines with timestamp,
  category, stable event, severity, and short scalars such as duration, bytes,
  intent, retention, or closed error category.
- Log hotkey, recording, transcription, cache, correction, translation, output,
  cancellation, retry, and export lifecycle—not payloads.
- Retain at most seven days and five megabytes, pruning during normal use.
  Debug/verbose is opt-in and bounded.
- Explicit Export saves to user choice or visible diagnostics cache. Bundle may
  include recent reports, version/bundle ID, redacted setup summary, and last
  48 hours of HoldType logs; it remains useful without runtime logs.
- Exclude keys, transcripts, prompts, dictionary/context, audio, headers,
  provider payloads/responses. Never upload automatically.
- Failed export leaves no misleading success. Prune/log failure preserves the
  current action where possible and exposes only compact local error.
- Fake-filesystem tests cover discovery/sort/errors/stale files, log append/
  formatting/pruning, bundle contents/redaction; bounded log stream/show checks
  instrumentation. Docs-only verification is `git diff --check`.
