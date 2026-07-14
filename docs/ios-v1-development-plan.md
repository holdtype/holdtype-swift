# HoldType iOS V1.1 Completion Plan

Status: canonical containing-app completion record; keyboard execution moved to
`docs/ios-keyboard-dictation-mvp-plan.md` on 2026-07-14.

Product behavior is governed by
`docs/specs/features/ios-v1-release.md`. Historical P0-P8, P5H, accepted-
History, and failed-History documents are evidence only. They are not active
implementation queues.

## Outcome

Finish the visible iPhone product without another architecture expansion:

- foreground Voice with Pending and Latest Result;
- Library and core Settings;
- compact successful-text History;
- one production Brand Stage Adaptive voice-command keyboard;
- public system Settings, app-owned keyboard dictation, and safe Latest
  fallback;
- signed-device qualification.

The user explicitly reprioritized working History ahead of the keyboard device
gate. K1 still gates keyboard-plus-voice release claims, but it did not block
finishing app-private History.

## Current Product State

Working and retained:

- foreground Voice, Done, Cancel, Retry, Discard, and Latest Result actions;
- always-on, non-expiring app-private Latest Result;
- compact, app-private History for up to 20 successful texts, including a flat
  full-text list, one-tap Copy, swipe Delete, conditional Play, Clear All, and
  the default-on `Save History` control;
- Dictionary, Voice Emoji Commands, and Replacement Rules;
- API key, transcription, correction, translation, recording, privacy, and
  Usage Estimate settings;
- containing-app practice field and the Brand Stage extension with punctuation,
  cursor Space, Delete repeat, adaptive Return, Globe, Light/Dark styling, and
  explicit Latest insertion;
- one production app-written, extension-read-only schema 3 snapshot containing
  at most one 10-minute Latest item;
- the real containing-app History destination and route; History is no longer a
  keyboard action.

Remaining release work:

1. Replace keyboard History with public system Settings and verify the normal
   four-tab app shell.
2. Prove on a signed physical iPhone that an explicit app-owned background
   session can receive bounded keyboard commands, control real audio, and return
   one result without launching the containing app or using private APIs.
3. After that gate passes, connect the existing recorder/OpenAI/Latest/History
   pipeline, finish compact setup/failure states, and qualify one TestFlight
   candidate. Exact work and stop conditions live in
   `docs/ios-keyboard-dictation-mvp-plan.md`.

## Execution Rules

- Build user-visible vertical slices; do not restore P5H capability families.
- Keep the working Voice/Pending path until its replacement is proven.
- Use one actor and one atomic record for compact History.
- History failure never changes a successful Latest Result into a failed
  dictation and never blocks Pending/audio cleanup.
- Delete legacy code only after the replacement has no production dependency
  on it.
- Each implementation checkpoint reports production and test line movement.
- Work only on `master`, preserve unrelated changes, and commit scoped paths.

## H1 — Compact History Repository

Create one app-private atomic record:

```text
schemaVersion
enabled
entries[0...20]
  resultID
  text
  createdAt
```

Required operations:

- load the confirmed record, defaulting a new install to enabled and empty;
- idempotently append by `resultID`, newest first, capped at 20;
- delete one exact entry;
- clear all while preserving enabled state;
- enable future appends;
- disable and clear in one atomic replacement.

The actor serializes all mutation. The file is protected, backup-excluded,
bounded, strict-schema JSON. Corruption and I/O failure are errors, not an empty
successful History.

Verification:

- missing, valid, corrupt, oversized, and unsupported records;
- cap, ordering, idempotent append, delete, clear, enable, disable-and-clear;
- atomic write failure leaves the previous confirmed record unchanged;
- concurrent mutations are serialized.

Exit: the compact repository passes independently and no UI or Voice path uses
legacy History policy, generation, outbox, failed rows, or retry audio.

## H2 — Production Append And Latest Semantics

Connect compact History immediately after successful Latest acceptance:

1. Latest remains the mandatory durable destination.
2. If compact History is enabled, append the accepted `resultID`, final text,
   and creation date idempotently.
3. If append fails, return success with a nonblocking local History warning.
4. Complete exact Pending/audio cleanup regardless of History outcome.

Also align Latest with V1.1:

- Latest is always on;
- remove the iOS `keepLatestResult` control and ignore its persisted value;
- remove the 24-hour Latest expiry without changing the short-lived Latest item
  inside the keyboard App Group snapshot;
- do not change macOS behavior.

Verification:

- Voice success produces Latest plus one History entry;
- the same result never duplicates;
- History disabled produces Latest only;
- History write failure still produces Latest and a warning;
- Retry/reconciliation never repeats provider work merely to append History.

Exit: a real successful containing-app dictation can create a compact History
entry, and Latest follows the canonical no-expiry, always-on contract.

## H3 — Finished History Surface

Replace the placeholder with one process-owned observable History owner and a
native SwiftUI surface.

Screen states:

- loading;
- disabled, with an explicit Enable action;
- empty: `No History Yet`;
- newest-first list;
- load failure: `History Unavailable` with Retry;
- nonblocking mutation warning while retaining the last confirmed list.

User actions:

- read complete text in the list without opening another screen;
- Copy with one tap;
- Delete one entry;
- Play only when the optional Recording Cache contains the exact accepted
  recording;
- confirmed Clear All;
- default-on `Save History` control;
- confirmed disable-and-clear;
- re-enable for future results only.

Update Setup, Privacy, and provider disclosure copy to state that up to 20
successful texts are stored locally when `Save History` is on. Remove claims
that History is absent or includes failed attempts.

Verification:

- owner state and stale-command tests;
- view/presentation tests for every state and confirmation path;
- compact-iPhone and iPad compatibility rendering;
- Simulator flow: create result -> flat History list -> Copy -> conditional
  Play -> swipe Delete -> Clear All -> disable -> re-enable -> future append.

Exit: Release navigation contains a useful History destination and never shows
the old unconditional unavailable text.

## H4 — Bounded Legacy Cleanup

After H1-H3 are green:

- remove old accepted/failed History services from production composition;
- stop failed-History scratch and accepted/failed recovery scheduling;
- remove only leaf source/test families with no surviving production consumer;
- retain the current Pending/Latest machinery until a smaller replacement is
  separately proven;
- remove superseded History policy/generation/outbox/failed-row tests together
  with the deleted code rather than porting them.

Exit:

- production composition owns only compact successful-text History;
- no failed-attempt History, retry-audio, policy-generation, or outbox service
  starts with the app;
- the cleanup checkpoint is materially net-negative in source and test lines;
- macOS and iOS remain green.

Completion evidence, 2026-07-13:

- production composition no longer starts the legacy accepted/failed History
  coordinator or failed-History retry providers;
- compact History repository, Voice acceptance, state owner, settings, and
  presentation paths pass their focused tests;
- signed iPhone and iPad Simulator builds launch with the sanitized automation
  environment; current UI acceptance verifies the populated newest-first flat
  list, exact Copy output, swipe Delete, conditional Play, and the
  non-destructive Clear confirmation path;
- macOS plus generic iOS builds succeed;
- H1-H4 changed 58 files with 2,833 insertions and 6,810 deletions: a net
  reduction of 3,977 lines;
- the broad persistence run executed 1,118 tests and reported 18 pre-existing
  issues in untouched legacy/timing paths; each timing-sensitive case passes
  in isolation, and no observed issue exercises the H4 changes.

The remaining deep persistence interlocks used by Pending and Latest are not a
user-visible History service. Their replacement and deletion now follow the
approved bounded plan in `docs/ios-v1-persistence-simplification-plan.md`.

## P1-P6 — Persistence Simplification And Legacy Retirement

Replace the active Pending/Latest compatibility graph with one compact
voice-state owner, detach capture and provider consent, prove zero production
references, and then delete the accepted/failed History, retry-audio, outbox,
generation, old delivery, and transaction-support families.

The focused execution order, complexity budget, deletion manifest, stop
conditions, and verification gates are defined in
`docs/ios-v1-persistence-simplification-plan.md`. This cleanup precedes K1 so
the keyboard work builds on the intended V1.1 persistence boundary.

Completion evidence, 2026-07-13:

- the private persistence lab is preserved at archive commit `b684741` and tag
  `archive-2026-07-13`;
- production now owns one compact Pending/Latest record, exact capture audio,
  standalone provider consent, and separate compact successful-text History;
- relaunch performs local reconciliation only, while provider Retry and
  Discard remain explicit user actions;
- `HoldTypePersistence` moved from 79 source and 55 test files to 23 source and
  12 test files;
- package Swift moved from 66,064 source plus 66,898 test lines to 9,254 source
  plus 8,030 test lines, a net reduction of 115,678 lines;
- the deletion checkpoint removed 107 obsolete files and 122,165 lines before
  the compact replacement was accounted for;
- the iOS scheme moved from 1,957 tests before deletion to 990 focused and
  surviving tests, all passing; package tests pass 193 plus 53;
- iOS Debug/Release, release-bundle isolation, and macOS builds pass; physical
  Data Protection, eviction, and App Group entitlement claims remain device
  gates.

## Keyboard MVP Continuation

The completed Brand Stage geometry, editing controls, bounded Latest snapshot,
and containing-app History remain the baseline. The former non-interactive
microphone and keyboard History request are superseded.

Current execution is defined only in
`docs/ios-keyboard-dictation-mvp-plan.md`:

- replace keyboard History with public system Settings;
- prove an app-owned Keyboard Dictation Session on a signed physical iPhone;
- connect the existing recorder/OpenAI/Latest/History pipeline only after that
  feasibility gate passes;
- finish bounded setup and failure states;
- qualify one TestFlight candidate.

The new plan preserves the existing one-item Latest projection and adds at most
one extension-written command record plus one app-written state/result record.
It does not restore any retired persistence family.

## Explicitly Deferred

- failed-attempt History and retry audio;
- background Quick Session and Live Activity;
- QWERTY, alphabet/number layouts, predictions, autocorrection, and typing
  dictionaries;
- production iPad floating keyboard and Stage Manager qualification;
- cloud sync, accounts, analytics, profiles, modes, and billing.

## Completion Dashboard

| Slice | Status |
| --- | --- |
| R0 Scope reset and stable baseline | Completed 2026-07-13 |
| H1 Compact History repository | Completed 2026-07-13 |
| H2 Production append and Latest semantics | Completed 2026-07-13 |
| H3 Finished History surface | Completed 2026-07-13 |
| H4 Bounded legacy cleanup | Completed 2026-07-13 |
| P1-P6 Persistence simplification and legacy retirement | Completed 2026-07-13 |
| Existing Brand Stage and Latest baseline | Engineering complete on Simulator 2026-07-14 |
| Keyboard Dictation MVP | Planned in `docs/ios-keyboard-dictation-mvp-plan.md` 2026-07-14 |

Compact History, Recording Cache playback, Brand Stage editing, and explicit
Latest insertion are complete in code. Settings replacement, actionable
keyboard dictation, and signed-device release qualification remain.
