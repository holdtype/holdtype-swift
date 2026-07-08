---
id: VT-070
title: Hotkey Umbrella
status: done
priority: P2
lane: hotkey
dependencies:
  - VT-002
  - VT-071
  - VT-072
  - VT-073
allowed_paths:
  - backlog/**
  - docs/specs/features/**
---

# VT-070 - Hotkey Umbrella

Status: done

## Goal

Close out global hotkey behavior after the contract and implementation slices
are complete.

## Child Tasks

- VT-002 hotkey behavior spec
- VT-071 hotkey service interface
- VT-072 hotkey toggles dictation action
- VT-073 hold-to-record decision slice

## Verification

- `python3 scripts/backlog_next.py --json`
- `git diff --check`

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Global hotkey contract, service/coordinator behavior, runtime status, and
  Settings display are present in the current checkout. No active hotkey
  backlog work remains under this umbrella.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
