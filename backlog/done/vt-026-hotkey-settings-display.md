---
id: VT-026
title: Hotkey Settings Display
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
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/global-hotkey.md
  - backlog/vt-026-hotkey-settings-display.md
---

# VT-026 - Hotkey Settings Display

Status: done

## Goal

Show the active dictation shortcut and activation mode in the native Settings
window.

## Scope

- Add a read-only Settings row for the active global hotkey.
- Show the activation mode as hold-to-record or toggle according to the
  product decision.
- Surface fallback or unavailable registration status when the hotkey service
  exposes it.

## Non-goals

- Do not add hotkey editing, capture UI, validation UI, or multiple hotkey
  slots.
- Do not add voice-agent, meeting, chat-agent, or platform-specific Linux
  hotkey setup.
- Do not implement actual hotkey registration in this task.

## Acceptance

- Settings displays the shortcut and activation mode using product language.
- If no global hotkey is active, Settings shows that manual menu recording is
  still available.
- No unsupported OpenWhispr hotkey slots or editing controls appear.

## Verification

- `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build`
- `git diff --check`

## Blocker Evidence

- Implemented the read-only Settings hotkey row in `VibeType/SettingsView.swift`.
- `timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' build` passed.
- `git diff --check` passed.
- Runtime QA is required because this task changes the visible Settings surface.
- Launched the freshly built app from
  `/Users/eugenepotapenko/Library/Developer/Xcode/DerivedData/vibetype-cgljxvuvdfxmqbeiqfwkdshvjovc/Build/Products/Debug/vibetype.app`
  as pid `43427`.
- Computer Use could not attach to the app by process name `VibeType`, app
  path, bundle id `potapenko.VibeType`, or product title `VibeType`; each
  returned `Invalid app`.
- Computer Use also timed out while inspecting `SystemUIServer`, so the menu
  bar item and Settings window could not be operated in this run.

## Resolution Path

Blocker category: runtime QA / Computer Use app inspection.

Follow-up: `VT-159` in `backlog/vt-159-hotkey-settings-runtime-closeout.md`.

Unblock condition: a runtime-capable tool can open the VibeType menu bar item,
open Settings, and inspect the Keyboard Shortcut row.

The current run could not finish this directly because the only exposed
Computer Use surface could not attach to the menu bar app or inspect
`SystemUIServer` within the bounded run.

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Keyboard Shortcut Settings already displays the preferred/current global
  hotkey, activation mode, registered/fallback/unavailable states, and
  manual-menu fallback copy.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
