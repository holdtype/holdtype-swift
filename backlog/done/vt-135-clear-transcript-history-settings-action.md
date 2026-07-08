---
id: VT-135
title: Clear Transcript History Settings Action
status: done
priority: P3
lane: history
parent: VT-130
dependencies:
  - VT-024
  - VT-133
allowed_paths:
  - VibeType/**
  - VibeTypeTests/**
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/transcript-history.md
  - backlog/vt-135-clear-transcript-history-settings-action.md
---

# VT-135 - Clear Transcript History Settings Action

Status: done

## Goal

Expose a native settings action that clears only persistent transcript history.

## Scope

- Add a Clear Transcript History action in Settings once the history store
  exists.
- Make the UI clear that disabling history stops future writes but does not
  clear saved entries.
- Disable or no-op safely when there is no persistent history to clear.
- Add focused tests where practical for the settings/store boundary.

## Non-goals

- Do not delete settings, Keychain secrets, raw audio cleanup state, or Last
  Transcript current-session state.
- Do not add per-row delete, search, notes, sync, accounts, or cloud APIs.
- Do not add OpenWhispr destructive delete behavior.

## Acceptance

- Clearing history removes only persisted history entries.
- The save-history toggle and clear action are understandable in the settings
  surface.
- Last Transcript remains a current-session value after clearing persistent
  history.

## Verification

- `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- `git diff --check`

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Settings already exposes Clear Transcript History, disables it when there
  are no entries, and clears recovery stores when history is disabled. The
  persistent-history wording is superseded by session-only recovery history.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
