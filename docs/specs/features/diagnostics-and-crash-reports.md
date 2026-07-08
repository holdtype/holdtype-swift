# Diagnostics And Crash Reports

## Goal

Give the user and a support agent a local, privacy-conscious way to find
HoldType crash reports and collect enough diagnostic context to understand why
the app failed.

Crash reports are primarily macOS system artifacts, not app-owned data. The app
should make those artifacts discoverable when it can, and should provide a safe
fallback path when the app cannot open after a crash.

## Scope

This spec covers:

- a Diagnostics section in Settings
- read-only discovery of HoldType crash reports written by macOS
- Finder reveal and path-copy actions for crash-report locations
- explicit user export of a diagnostic bundle
- safe, compact runtime logging and local runtime-log retention
- the manual fallback path for agents when the app cannot launch

## Non-goals

- automatic crash upload
- analytics, telemetry, account-backed support, or cloud sync
- deleting, moving, or rewriting macOS system crash reports
- collecting raw audio, transcripts, prompts, dictionary entries, nearby text
  context, API keys, authorization headers, provider payloads, or full provider
  responses
- installing a custom crash handler or attempting to replace macOS CrashReporter
- retaining hidden recovery artifacts after crashes
- automatic collection of broad macOS system logs
- long-term app-owned runtime log archives

## User-visible behavior

- Settings should include a dedicated Diagnostics section after the main MVP
  setup and recording-cache sections.
- Diagnostics should explain that macOS stores crash reports outside the app,
  typically in `~/Library/Logs/DiagnosticReports/`.
- Diagnostics should search for HoldType crash reports in the current user's
  diagnostic reports directory. It may also show a read-only unavailable state
  for system-wide diagnostic report locations that cannot be read.
- Crash-report discovery should match the HoldType process name and bundle
  identity, including modern `.ips` reports and older `.crash` reports when
  present.
- Diagnostics should list recent HoldType crash reports with file name, date,
  size, and location. The newest report should be easy to identify.
- If no HoldType crash reports are found, Diagnostics should show an empty
  state instead of pretending that the app has never crashed.
- Diagnostics should provide:
  - Reveal in Finder for the diagnostic reports directory
  - Reveal in Finder for a selected crash report
  - Copy Path for the diagnostic reports directory or selected report
  - Refresh
  - a short Recent Runtime Events view when app-owned runtime logs exist
  - Copy Recent Runtime Events when app-owned runtime logs exist
  - Reveal Runtime Logs when app-owned runtime logs exist
  - Export Diagnostic Bundle when bundle export is implemented
- Diagnostics must not include a Delete Crash Reports action in the MVP.
- A diagnostic bundle should be created only after an explicit user action. It
  should be saved to a user-chosen location or a visible app-owned diagnostics
  cache location.
- A diagnostic bundle may include recent HoldType crash reports, app version
  and bundle identity, a redacted settings/setup summary, and recent
  HoldType-filtered runtime logs.
- A diagnostic bundle must clearly exclude API keys, transcripts, prompts,
  custom dictionary contents, nearby text context, raw audio, provider payloads,
  and full provider responses.
- Runtime dictation logs should include compact lifecycle events such as hotkey
  press/release, recording start/stop, recording duration and byte count,
  transcription start/success/failure category, and recording-cache
  keep/delete outcome.
- Runtime logs may also include compact correction, translation, output-delivery,
  cancellation, retry, and diagnostics-export outcomes. They must use stable
  event names and short operator categories rather than user-facing payloads.
- Runtime logs should be stored as app-owned diagnostic text lines in the
  user's Library cache hierarchy so the user can inspect or send recent lines
  without opening Console.app.
- Runtime log retention should be bounded by both age and size. The default
  policy is to keep at most seven days and at most five megabytes of app-owned
  runtime logs, pruning older or excess files during normal app use.
- Diagnostic bundle export should include only a bounded recent runtime-log
  window, defaulting to the last 48 hours. Export should remain useful when
  runtime-log collection is unavailable.
- When the app cannot launch, the documented fallback path is to inspect or
  send matching files from `~/Library/Logs/DiagnosticReports/` directly.

## Invariants

- Diagnostics is local-only. It must not upload reports, logs, or bundles.
- Crash report discovery is read-only.
- System crash reports remain system-owned files. HoldType may reveal, copy
  paths, or include a user-selected copy in a diagnostic bundle, but it must not
  delete or mutate the originals.
- Default product logs must stay short, scannable, and free of dictated
  content or sensitive payloads.
- App-owned runtime logs must be local-only, bounded, and safe to attach to a
  support request after user review.
- Debug or verbose diagnostics must be opt-in and bounded.
- Diagnostic bundle generation must not require live OpenAI, microphone,
  Keychain, Accessibility, Input Monitoring, or active-app access.

## Edge cases and failure policy

- If the diagnostic reports directory does not exist, Diagnostics should show a
  missing-directory state and still offer the canonical path.
- If the directory exists but cannot be read, Diagnostics should show a local
  read error without blocking the rest of Settings.
- If a crash report is removed by the system or another process between list
  and reveal/export, the app should refresh and show that the report is no
  longer available.
- If bundle export fails, the app should show a visible local error and should
  not leave behind a misleading success file.
- If runtime log collection is unavailable, the diagnostic bundle may still be
  created with crash reports and app metadata.
- If runtime log pruning fails, Diagnostics should keep the current user action
  working where possible and surface only a compact local diagnostics error if
  export or display cannot proceed.
- If a crash or interruption happens during recording, raw audio handling stays
  governed by recording cache settings and privacy specs. Diagnostics must not
  create a hidden raw-audio archive.

## Route / state / data implications

- Diagnostics should be a Settings sidebar destination, not a permission state
  or recording-cache subsection.
- Crash report state is derived from the file system at refresh time and should
  not be stored in UserDefaults.
- Generated diagnostic bundles are app-owned derived artifacts. If retained,
  they belong in a visible diagnostics cache under the user's Library cache
  hierarchy, or in a user-selected export location.
- Runtime logs should use Apple's unified logging APIs with a HoldType
  subsystem and narrow categories. Logs should be filterable by process,
  subsystem, or category.
- App-owned runtime logs belong under the user's Library cache hierarchy,
  separate from macOS crash reports and recording cache audio.
- Runtime log lines should be structured enough for support agents to parse
  but readable enough for users to inspect. A line may include timestamp,
  category, event name, severity, and short scalar fields such as duration,
  byte count, output intent, retention policy, or error category.
- The canonical manual lookup path for this Mac user is:
  `~/Library/Logs/DiagnosticReports/HoldType*.ips`.

## Verification mapping

- Add fake-file-system tests for report discovery, sorting, filtering,
  missing-directory state, read errors, stale files, and bundle contents.
- Add Settings navigation tests for the Diagnostics item and empty-state
  rendering.
- Add tests or review checks that diagnostic bundle metadata is redacted and
  excludes user content, raw audio, API keys, prompts, provider payloads, and
  transcripts.
- Add fake-file-system tests for runtime-log append, recent-line formatting,
  age/size pruning, and diagnostic bundle inclusion.
- Verify log instrumentation with a bounded build/run loop and filtered
  `log stream` or `log show` command when implementation adds runtime logs.
- For docs-only updates, `git diff --check` is sufficient.
