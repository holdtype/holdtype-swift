# Runtime Logs And Diagnostic Bundle

- Node type: leaf
- Status: Active
- Contract revision: `holdtype.macos.diagnostics.runtime-logs@2`
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
- Event producers enqueue bounded metadata without waiting for disk writes or
  retention scans; preserve event-time timestamps and order. Explicit export
  includes preceding queued events. Diagnostic overload never blocks capture.
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

## Responsiveness delta, revision 2

User-approved start-responsiveness plan, 2026-09-09. Background preparation
removes optional work from the microphone start path. Existing privacy,
durability, export, and capture-authority boundaries remain protected.
Verification covers ordering, cancellation, late completion, and local runtime.
