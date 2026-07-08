---
id: VT-183
title: Diagnostic Bundle Export
status: done
priority: P2
lane: settings
dependencies:
  - VT-182
allowed_paths:
  - backlog/vt-183-diagnostic-bundle-export.md
  - docs/specs/features/diagnostics-and-crash-reports.md
  - docs/specs/features/privacy-and-permissions.md
  - VibeType/**
  - VibeTypeTests/**
verification:
  - git diff --check
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
---

# VT-183 - Diagnostic Bundle Export

Status: done
Priority: P2
Lane: settings
Dependencies: VT-182
Expected outputs: explicit diagnostic bundle export flow and redaction tests
Verification: git diff --check; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test

## Goal

Let the user explicitly export a local diagnostic bundle that can be sent to an
agent for crash investigation.

## Scope

- Add Export Diagnostic Bundle to the Diagnostics Settings section.
- Include recent VibeType crash reports and safe app metadata.
- Include only redacted settings/setup metadata needed for troubleshooting.
- Save to a user-chosen location or a visible app-owned diagnostics cache
  location.
- Add tests proving excluded content is not included.

## Non-goals

- Automatic uploads.
- Broad system log collection.
- Raw audio, transcripts, prompts, dictionary entries, nearby text context,
  API keys, provider payloads, or full provider responses.
- Deleting crash reports or cache files.

## Acceptance

- Bundle generation requires an explicit user action.
- Bundle contents are deterministic enough for tests.
- Bundle generation failure produces a visible local error.
- The exported bundle remains local unless the user manually sends it.

## Completion Notes

- Added explicit Export Diagnostic Bundle action in Diagnostics Settings.
- Diagnostic bundles are local app-owned directories under the VibeType
  diagnostics cache, revealed in Finder after export.
- Bundles include recent VibeType crash reports plus `manifest.json` and
  `README.txt` with app metadata and explicit excluded-content metadata.
- Added tests for bundle export with reports and without reports.
