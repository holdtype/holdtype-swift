# Crash Discovery And Actions

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.diagnostics-and-crash-reports@1`
- Clauses: `DIAGNOSTICS.CRASH`, `DIAGNOSTICS.ACTIONS`
- Read when: macOS report discovery, list states, Finder, path copy, or no-launch fallback is in scope.
- Do not read when: only runtime log formatting/export is in scope.
- Maximum size: 100 physical lines.

- Settings has a dedicated Diagnostics destination. Explain macOS ownership and
  canonical user directory `~/Library/Logs/DiagnosticReports/`.
- At refresh, read current-user reports matching HoldType process/bundle,
  modern `.ips` and legacy `.crash`; system-wide unreadable locations may be
  shown as unavailable. List recent file name/date/size/location with newest obvious.
- No matches is an honest empty state, not proof the app never crashed.
- Actions: reveal reports directory or selected report, copy either path,
  Refresh, and runtime/bundle actions when available. Never offer Delete.
- Missing directory still displays canonical path. Unreadable directory shows
  local error without blocking Settings. A report removed between list/action
  triggers refresh and unavailable feedback.
- Crash state is filesystem-derived, never UserDefaults. Manual fallback when
  app cannot launch is direct inspection/sending of
  `~/Library/Logs/DiagnosticReports/HoldType*.ips`.
