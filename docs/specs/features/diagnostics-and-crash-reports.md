# Diagnostics And Crash Reports

- Node type: hybrid
- Contract ID: `holdtype.macos.diagnostics-and-crash-reports`
- Domain ID: `holdtype.macos.diagnostics`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released
- Contract revision: `holdtype.macos.diagnostics-and-crash-reports@1`
- Read when: macOS crash discovery, runtime diagnostics, support-bundle export, or manual fallback is in scope.
- Do not read when: iOS diagnostics or general test selection is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Give users/support a local privacy-safe way to discover system-owned HoldType
crash reports and export bounded redacted context. No automatic upload,
telemetry, cloud support, crash-handler replacement, broad system logs, hidden
recovery artifacts, or mutation of macOS crash reports is permitted.

## Children

- [Crash discovery and actions](diagnostics-and-crash-reports/crash-discovery-and-actions.md) — matching, list/empty/error states, Finder, Copy Path, Refresh, and manual fallback.
- [Runtime logs and bundle](diagnostics-and-crash-reports/runtime-logs-and-bundle.md) — compact events, retention, explicit export, redaction, storage, failure, and verification.

## Invariants

- Diagnostics is local-only/read-only for system reports. HoldType may reveal,
  copy a path, or copy selected reports into an explicit bundle, never delete,
  move, or rewrite originals.
- Runtime logs are short, bounded, app-owned, inspectable, and contain no user
  content, secrets, provider payloads, or raw audio.
- Bundle creation requires explicit action and no OpenAI, microphone, Keychain,
  Accessibility, Input Monitoring, or active-app access.
- Recording-crash audio remains owned by privacy/cache/durability contracts;
  Diagnostics creates no audio archive.
