---
id: VT-159
title: Hotkey Settings Runtime Closeout
status: done
priority: P2
lane: settings
parent: VT-020
dependencies:
  - VT-013
  - VT-071
  - VT-073
allowed_paths:
  - VibeType/**
  - backlog/vt-026-hotkey-settings-display.md
  - backlog/vt-159-hotkey-settings-runtime-closeout.md
verification:
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build
  - git diff --check
---

# VT-159 - Hotkey Settings Runtime Closeout

Status: done

## Goal

Close the runtime QA gap for `VT-026` by verifying the hotkey display in the
real macOS Settings window.

## Current Blocker

The implementation build passed, but the scheduled implementer run could not
operate the Settings surface: Computer Use returned `Invalid app` for
`VibeType`, the built app path, `potapenko.VibeType`, and `VibeType`, then timed
out while inspecting `SystemUIServer`.

## Scope

- Build the macOS app from the current checkout.
- Launch a freshly built, run-owned app instance.
- Open Settings through the real menu bar UI using Computer Use or a
  macOS-capable runtime UI tool.
- Inspect the Keyboard Shortcut section.
- If the row matches the spec, mark `VT-026` done with runtime QA evidence.
- If the row does not match, fix the smallest Settings display issue before
  marking `VT-026` done or blocked.

## Non-goals

- Do not add hotkey editing, capture UI, validation UI, or multiple hotkey
  slots.
- Do not implement actual global hotkey registration.
- Do not use deferred iOS/simulator lanes for this macOS closeout.

## Acceptance

- Runtime QA evidence records scenario, actions, expected result, observed
  result, tool used, and blocker if any.
- Settings shows `Option+Space - Hold to record` when no fallback is active.
- Settings explains that no global hotkey is active yet and that Start
  Recording in the menu remains available.
- No unsupported OpenWhispr hotkey editing controls appear.
- `VT-026` is marked `done` only after the runtime Settings row is verified or
  is left `blocked` with fresh evidence.

## Verification

- `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- Bounded runtime QA of the Settings Keyboard Shortcut row.
- `git diff --check`

## Resolution Path

Blocker category: runtime QA / Computer Use app inspection.

Unblock condition: Computer Use or a macOS-capable MCP/runtime tool can attach
to the running menu bar app or `SystemUIServer`, open Settings, and inspect the
Keyboard Shortcut section.

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: This closeout task is no longer actionable: Keyboard Shortcut Settings
  display is implemented and the stale runtime-QA blocker is superseded.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
