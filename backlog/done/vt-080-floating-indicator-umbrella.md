---
id: VT-080
title: Floating Indicator Umbrella
status: done
priority: P3
lane: indicator
dependencies:
  - VT-004
  - VT-081
  - VT-082
allowed_paths:
  - backlog/**
  - docs/specs/features/**
---

# VT-080 - Floating Indicator Umbrella

Status: done

## Goal

Close out the MVP floating indicator after the spec and skeleton tasks are
complete.

## Child Tasks

- VT-004 floating indicator spec
- VT-081 indicator state contract
- VT-082 indicator panel skeleton

## Verification

- `python3 scripts/backlog_next.py --json`
- `git diff --check`

## Audit Closeout

Closed by backlog audit on 2026-07-07.

- Disposition: Floating indicator contract and app integration are already present in the
  current checkout. No active indicator backlog work remains under this
  umbrella.
- Verification: backlog metadata audit only; no product code was changed
  in this closeout.
