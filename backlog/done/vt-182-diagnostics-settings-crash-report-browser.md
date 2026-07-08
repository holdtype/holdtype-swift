---
id: VT-182
title: Diagnostics Settings Crash Report Browser
status: done
priority: P1
lane: settings
dependencies:
allowed_paths:
  - backlog/vt-182-diagnostics-settings-crash-report-browser.md
  - docs/specs/features/diagnostics-and-crash-reports.md
  - docs/specs/features/settings-and-secret-storage.md
  - VibeType/**
  - VibeTypeTests/**
verification:
  - git diff --check
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
---

# VT-182 - Diagnostics Settings Crash Report Browser

Status: done
Priority: P1
Lane: settings
Dependencies: none
Expected outputs: Diagnostics Settings section, crash report discovery service, focused tests
Verification: git diff --check; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test

## Goal

Add the first Diagnostics Settings section so the user can find recent VibeType
macOS crash reports without leaving the app.

## Scope

- Add a Diagnostics item to the Settings sidebar.
- Add a Diagnostics Settings section with empty, loaded, and read-error states.
- Add a focused service/model that discovers matching VibeType `.ips` and
  `.crash` reports from the user diagnostic reports directory.
- Provide Reveal in Finder, Copy Path, and Refresh actions.
- Add fake-file-system unit coverage for matching, sorting, missing-directory,
  read-error, and stale-file behavior.

## Non-goals

- Delete, move, or rewrite crash reports.
- Generate diagnostic bundles.
- Add runtime log instrumentation.
- Add automatic upload or telemetry.

## Acceptance

- Diagnostics appears as a stable Settings sidebar destination.
- Recent VibeType crash reports are listed with file name, date, size, and
  location when present.
- No VibeType reports found is represented as an empty state.
- Discovery is read-only and does not access live OpenAI, microphone,
  Keychain, Accessibility, Input Monitoring, or active-app content.

## Completion Notes

- Added `DiagnosticsService` for read-only discovery of VibeType `.ips` and
  `.crash` reports from the current user's DiagnosticReports directory.
- Added `DiagnosticsSettingsSection` and wired Diagnostics into the Settings
  sidebar/detail flow with Refresh, Reveal, and Copy Path actions.
- Added focused `DiagnosticsServiceTests` and updated `SettingsNavigationItem`
  coverage.
- Completed in direct-chat mode after the user clarified that backlog should
  not be the default workflow for ordinary chat tasks.
