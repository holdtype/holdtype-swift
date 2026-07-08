---
id: VT-184
title: Runtime Log Diagnostics Instrumentation
status: done
priority: P2
lane: settings
dependencies:
  - VT-182
allowed_paths:
  - backlog/vt-184-diagnostics-runtime-log-instrumentation.md
  - docs/specs/features/diagnostics-and-crash-reports.md
  - docs/specs/features/privacy-and-permissions.md
  - VibeType/**
  - VibeTypeTests/**
  - docs/qa/**
verification:
  - git diff --check
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
---

# VT-184 - Runtime Log Diagnostics Instrumentation

Status: done
Priority: P2
Lane: settings
Dependencies: VT-182
Expected outputs: compact Logger instrumentation and bounded verification evidence
Verification: git diff --check; xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build

## Goal

Add high-signal VibeType runtime logs that help explain window actions,
diagnostics actions, and recoverable failure paths without exposing user
content.

## Scope

- Add focused `OSLog.Logger` categories for Diagnostics and any adjacent
  window/action path touched by this task.
- Log concise action boundaries and local error categories only.
- Document or record a bounded `log stream` or `log show` verification path.
- Add tests or review checks for redaction-sensitive code paths when practical.

## Non-goals

- Print-based telemetry.
- Dense state dumps.
- Logging transcripts, prompts, dictionary entries, nearby text context, raw
  audio, API keys, provider payloads, or full provider responses.
- Adding analytics, automatic uploads, or account-backed support.

## Acceptance

- Default logs remain short and scannable.
- Logs are filterable by VibeType process, subsystem, or category.
- Verification proves at least one new diagnostics action emits exactly one
  useful log line or a small bounded sequence.

## Completion Notes

- Added `OSLog.Logger` instrumentation in `DiagnosticsService` under the
  `Diagnostics` category.
- Logs cover refresh, reveal, path-copy, and export outcomes with compact
  counts or categories only.
- Logs do not include API keys, transcript text, prompts, raw audio, provider
  payloads, full provider responses, or copied filesystem paths.
- Added focused test coverage through an injectable diagnostics event logger so
  event emission is verified without relying on live unified-log persistence.
