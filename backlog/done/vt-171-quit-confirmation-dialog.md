---
id: VT-171
title: Quit Confirmation Dialog
status: done
priority: P1
lane: menu-bar
dependencies:
allowed_paths:
  - docs/specs/features/menu-bar-app-shell.md
  - VibeType/VibeTypeApp.swift
  - VibeTypeTests/VibeTypeTests.swift
  - backlog/vt-171-quit-confirmation-dialog.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - git diff --check
---

# VT-171 - Quit Confirmation Dialog

Status: done
Priority: P1
Lane: menu-bar
Dependencies: none
Expected outputs: menu shell spec update, confirm-on-quit app delegate behavior, fake-backed tests
Verification: `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`; `git diff --check`

## Goal

Prevent accidental VibeType termination from the menu bar Quit action,
application menu Quit, Dock Quit, or `Command+Q`.

## Scope

- Update the menu bar app shell spec with confirm-on-quit behavior.
- Add a native confirmation dialog before normal app termination proceeds.
- Keep ordinary Settings and Transcript History window closing separate from
  app termination.
- Add fake-backed tests for the termination decision without showing a real
  `NSAlert`.

## Non-goals

- Add a user setting to disable the confirmation dialog.
- Change Settings or Transcript History close-window behavior.
- Change recording, transcription, paste, history, or permission behavior.

## Acceptance Criteria

- User-initiated app termination asks for confirmation before quitting.
- Cancel keeps VibeType running.
- Confirm proceeds through normal app termination cleanup.
- Closing Settings or Transcript History windows does not show the quit
  confirmation.
- The task is marked done only after verification is recorded.

## Result

- Updated the menu bar app shell spec to require confirmation before app
  termination from Quit, Dock Quit, and `Command+Q`.
- Added a native AppKit quit confirmation through the existing app delegate
  termination hook.
- Kept termination cleanup in `applicationWillTerminate`, so recovery history
  and hotkey cleanup run only after confirmed termination.
- Added fake-backed tests for cancel/quit decision mapping and delegate
  injection without showing a real `NSAlert`.

## Verification

- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- Passed: `git diff --check`
- Tooling: `xcodebuild` fallback after MCP discovery exposed iOS/simulator
  tools but no usable macOS test runner in this session.
- Runtime QA: required and passed. Launched the freshly built
  `VibeType.app`, sent the standard Quit request, verified the native
  `Quit VibeType?` dialog through Computer Use, and clicked `Quit VibeType`;
  the app process exited. A separate older `vibetype.app` process was already
  running from another DerivedData path and was left untouched.
