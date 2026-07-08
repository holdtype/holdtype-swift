---
id: VT-122
title: Controller Start Stop Recording Flow
status: done
priority: P2
lane: controller
parent: VT-120
dependencies:
  - VT-043
  - VT-121
allowed_paths:
  - VibeType/**
  - VibeTypeTests/**
  - docs/specs/features/microphone-text-input.md
  - docs/specs/features/menu-bar-app-shell.md
  - backlog/vt-122-controller-start-stop-recording-flow.md
---

# VT-122 - Controller Start Stop Recording Flow

Status: done

## Goal

Wire the controller's start and stop actions through the recording boundary.

## Scope

- Start recording only from idle.
- Stop only an active recording and move to transcribing when an artifact is
  returned.
- Ignore repeated start or stop actions that would create parallel work.
- Serialize overlapping menu and hotkey start/stop requests through one
  controller path.
- Use fake-backed tests for state transitions.

## Acceptance

- Start from idle enters recording.
- Stop from recording produces the next transcribing-ready state.
- Repeated start while recording and start while transcribing are no-ops or
  visible blocked states, not parallel recordings.
- Repeated stop while a stop is already being handled does not start duplicate
  transcription work.
- Stop without an active recording is a no-op or visible blocked state.

## Source Evidence

- OpenWhispr uses start and stop locks to prevent overlapping recording work in
  `references/openwhispr-main/src/hooks/useAudioRecording.js`.
- The same hook rejects recording start while the reference audio manager is
  already recording or processing.

## Verification

- `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`
- `git diff --check`

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Controller start/stop recording flow is already implemented: idle starts
  recording, recording stops and transcribes, transcribing/repeated actions
  are ignored or serialized, and fake-backed tests cover the flow.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
