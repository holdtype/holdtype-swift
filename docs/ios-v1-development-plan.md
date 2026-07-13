# HoldType iOS V1.1 Development Plan

Status: canonical implementation roadmap; approved 2026-07-13.

`V1.1` is the first planned iOS release designation; no earlier iOS V1.0 is
assumed to have shipped.

This plan supersedes the implementation order in
`docs/ios-product-portability-plan.md` and
`docs/ios-keyboard-development-plan.md`. Those files remain historical research
and gate evidence. Product behavior is governed by
`docs/specs/features/ios-v1-release.md`.

## Outcome

Deliver a compact, testable iPhone product with:

- working foreground Voice;
- one Pending and one Latest Result;
- Dictionary, Voice Emoji Commands, and Replacement Rules;
- core Settings and privacy setup;
- a simple accepted-text History;
- a usable `en-US` keyboard with a dedicated, honest voice action;
- signed physical-iPhone evidence.

The plan is complete only when the whole user path works. A hidden backend,
green simulator build, or placeholder screen is not a completed feature.

## Starting State At R0 Entry

Already useful and retained:

- portable Domain and OpenAI packages;
- iPhone/iPad containing-app shell;
- foreground Voice UI and provider pipeline;
- Latest Result actions;
- Library editors;
- API key and core Settings;
- app/extension target isolation.

Incomplete or misleading:

- History is a placeholder while its hidden backend dominates the codebase;
- the keyboard is a 199-line Phase-0 probe, not QWERTY;
- the production keyboard bridge has no accepted-result writer;
- physical keyboard and microphone gates remain open;
- stopped P5H-2 WIP leaves the current checkout uncompilable until it is
  removed or completed solely enough to delete safely.

## Working Rules

- Do not resume P5H-2, P5H-3, P5H-4, P6, P7, or P8 as previously written.
- No branch is created; all checkpoints remain scoped commits on `master`.
- Preserve unrelated work and stage only owned paths.
- Simplification proceeds behind existing facades where that avoids rewriting
  UI and provider code simultaneously.
- Delete a legacy subsystem only after the replacement vertical path passes.
- Do not retain dead code merely because it has extensive tests; Git is the
  archive.
- Every checkpoint reports user-visible progress, source/test movement, and
  exact deferred risk.
- Physical-device requirements remain gates and are never inferred from the
  simulator.

## R0 — Scope Reset And Stable Baseline

Goal: stop the old train and restore one explicit baseline.

Tasks:

- commit the new V1.1 spec, audit, and roadmap;
- mark the old portability roadmap as superseded;
- mark the old keyboard plan as a feasibility appendix;
- mark accepted/failed History transaction specs as deferred historical
  contracts;
- decide the stopped P5H-2 state explicitly:
  - after confirming those edits are agent-owned and receiving authorization
    to discard them, restore only the two uncommitted WIP files to their
    committed contents;
  - do not stage either WIP file with this documentation checkpoint;
  - revert dependent test commit `b50645a` first, then implementation commit
    `053fa33`, using normal scoped commits without rewriting history;
  - build after each revert so the dependent test never remains on top of a
    removed implementation;
- restore a compiling and tested app-only Voice baseline.

Exit:

- the checkout compiles from committed source;
- no active plan names P5H as the next slice;
- production behavior remains disclosure v1/app-only;
- no partial captured-History code is selected by production.

Verification includes the full matching iOS foreground-processor test suite,
not only a build, plus the macOS baseline and `git diff --check`.

Completed 2026-07-13. The two authorized reverts restored the app-only Voice
baseline, and the remaining dependent workflow branch was removed rather than
reviving P5H. Simulator keyboard enablement and interaction evidence is recorded
in `docs/qa/runs/ios-r0-baseline-keyboard-simulator-2026-07-13.md`; that evidence
does not satisfy D0's signed physical-iPhone gate.

## D0 — Immediate Signed Keyboard Voice Feasibility Gate

Goal: settle the defining iOS boundary before another persistence or keyboard
expansion.

### D0-prep — Bounded Probe

Build only the smallest signed-device probe required for the decision:

- one microphone control in the existing Phase-0 keyboard;
- one candidate containing-app handoff implemented through public API;
- the current simple App Group result and explicit Insert control;
- no QWERTY engine, background recording, command queue, or new persistence
  family.

### Required signed physical-iPhone checks

1. app and extension install with the intended App Group;
2. keyboard enablement and Globe switching work;
3. ordinary extension typing works with Full Access off;
4. the microphone control either performs a supported containing-app handoff
   or produces a documented negative result;
5. the manual return path to the original host is understood;
6. App Group read/write behavior is recorded with Full Access off and on;
7. one explicit Insert Result works in Notes with exactly one insertion per
   tap and no automatic insertion after refresh or relaunch;
8. secure-field, phone-pad, and host-opt-out behavior is recorded;
9. the app and extension are force-quit between stages and snapshot expiry is
   inspected.

Decision:

- A positive supported-handoff result fixes app foreground recording, manual
  return, and explicit Insert Result as the V1.1 interaction.
- A negative handoff result is a no-go for the keyboard-plus-voice V1.1 in the
  release contract. Work stops for explicit app-only rescoping; an
  instruction-only button is not counted as V1.1 completion.
- Background Quick Session is not a V1.1 workaround.

After a positive result, update the canonical setup/privacy copy contract with
the exact Full Access requirement and the minimal App Group fields before R6.
The probe code is then either reused narrowly or deleted.

Exit evidence belongs in one dated `docs/qa/runs/` document. Simulator evidence
cannot pass D0. R1 and later milestones do not start until D0 is positive or
the user explicitly approves a different product scope.

## R1 — Detach Dormant History From Production

Goal: stop paying runtime and maintenance cost for an invisible feature.

Tasks:

- first detach provider consent from
  `IOSAcceptedHistoryCoordinatorProcessContextRegistry` into one standalone,
  app-private versioned consent owner while preserving current behavior;
- first extract `AppOnlyPendingLifecycleRecovery` over the current Pending
  stores so process loss still maps processing work to visible Retry/Discard
  without a provider call;
- remove `IOSFailedHistoryService` from production composition;
- remove failed-History scratch startup maintenance;
- remove accepted/failed History recovery from ordinary lifecycle scheduling;
- preserve only the narrow app-only Pending and Latest operations required by
  current Voice;
- temporarily remove the History tab from Release navigation rather than ship
  the placeholder;
- keep legacy types compiled only where required for the next replacement
  checkpoint, not as production services.

Verification:

- app launch and every current Voice/Library/Settings route;
- fake-backed Voice to Latest;
- relaunch Pending Retry/Discard;
- no History, outbox, or failed-retry maintenance in production logs;
- macOS regression.

Exit:

- production composition has no dormant failed-History service;
- app-only Voice remains behaviorally intact;
- provider consent no longer constructs History, outbox, delivery, or failed-row
  stores;
- Pending process-loss recovery has an explicit app-only owner;
- Release navigation has no placeholder destination.

## R2 — Compact Persistence Vertical Slice

Goal: replace capability machinery with records matching the product.

### R2.1 Build Compact Repositories Off The Production Path

Build the replacements without mixing old and new transitions:

- `PendingAttemptRepository` owns one `attemptID`, one metadata JSON, and one
  protected audio file;
- Pending states are `ready`, `processing`, `failed`, and
  `accepted(resultID)` while local cleanup is unfinished;
- `LatestResultRepository` stores `resultID`, `sourceAttemptID`, accepted text,
  and creation time, with Load, Replace, and Clear;
- `AcceptedTextHistoryRepository` stores at most 20 text-only entries and uses
  `resultID` as its idempotency key;
- the History enabled flag and entries share one atomic repository record so
  disable-and-clear cannot publish a disabled flag while retaining old text;
- all three use atomic local publication, backup/file protection appropriate to
  their data, and bounded file operations.

Latest is always on for iOS V1.1. Remove the iOS `keepLatestResult` control and
migrate existing values to the always-on contract without changing macOS.

### R2.2 One App-Only Voice Cutover

Add one `AppOnlyVoicePersistence` facade that owns Prepare, Process, Accept,
Recover, Retry, Discard, and Latest. Switch the complete foreground vertical
path in one checkpoint; do not connect compact Pending to legacy acceptance or
compact Latest to legacy Pending.

On provider success:

1. durably replace Latest with `resultID` and `sourceAttemptID`;
2. mark the matching Pending attempt `accepted(resultID)`;
3. attempt an idempotent History append when `Save History` is on, surfacing a
   local warning if it fails;
4. always retire the exact audio and Pending metadata regardless of the History
   append result.

On relaunch, a Pending `attemptID` matching Latest `sourceAttemptID` completes
an idempotent History append when `Save History` is still on and then completes
local cleanup without a provider call, even if the accepted marker was not yet
written. History failure still cannot block that cleanup. An
`accepted(resultID)` Pending without Latest, including after user Clear,
finishes provider-free audio and metadata cleanup from its own terminal state.
A processing attempt without matching Latest becomes visibly retryable;
recovery never performs the retry itself.

### R2.3 Connect Compact Accepted Text History

- append the same `resultID` at most once;
- list newest first, delete one, and clear all;
- keep append failure isolated from Latest success;
- implement the default-on `Save History` preference and confirmed
  disable-and-clear behavior without generations or cutover policy.

Verification:

- semantic repository tests for missing, valid, corrupt, atomic failure, cap,
  idempotent append, crash windows, and concurrent mutation;
- process relaunch with Latest and one Pending;
- relaunch with accepted Pending after Latest was cleared;
- no provider call during recovery;
- integration Voice success -> Latest + History;
- History failure -> Latest still succeeds.

Exit:

- current Voice uses compact Pending and Latest;
- compact accepted History owns all user-visible rows;
- no current product path depends on policy generations, outboxes, or failed
  History.

## R3 — Delete Legacy History And Reduce Tests

Goal: realize the simplification after R2 is green.

Tasks:

- delete obsolete leaf families after R2 proves they have no surviving
  production consumer:
  - accepted-History coordinator/outbox/pending replacement;
  - failed-History rows, retry, audio cleanup, and scratch;
  - History policy/cutover;
  - captured foreground History mode;
  - delivery capabilities used only by those paths;
  - replaced `IOSPendingRecording*`, `IOSForegroundVoiceCaptureSource*`, and
    old Pending journal/audio capabilities;
- because SwiftPM includes all files under a target's `Sources` directory, do
  not rely on per-file target membership; remove dependencies leaf-first and
  delete each source family when the target still compiles without it;
- remove their tests and QA-only fixtures;
- preserve a short migration note only if a publicly distributed build wrote
  these records; otherwise no speculative migration is added;
- stop including package test source folders in `HoldTypeIOSTests`;
- run package suites in their owning packages and keep compact iOS integration
  coverage.

Exit:

- no obsolete History symbol is linked into the iOS app;
- package and iOS test ownership is non-duplicated;
- source and test counts drop materially;
- app, compact History, and macOS remain green.

Expected direction after R3:

- remove approximately 36,000-37,000 production History lines;
- remove approximately 42,000-43,000 History test lines;
- remove the replaced Pending/capture implementation and its duplicated tests;
- avoid replacing them with another transaction framework.

## R4 — Simplify Foreground Voice And Consent

Goal: make the main product path understandable and maintainable.

Tasks:

- converge on a `@MainActor` Voice presentation model and one Voice service
  actor;
- replace the large closure graph with a small set of typed clients;
- remove scene/capability state that no surviving multiwindow behavior needs;
- finish compacting the standalone consent owner from R1 to one versioned
  accepted/revoked record checked before each provider stage;
- preserve real cancellation, bounded provider timeouts, recording finalization,
  one Pending, and non-replay guarantees;
- keep existing correction, translation, Dictionary, emoji, and replacement
  behavior.

Exit:

- the main foreground workflow can be described by one short state diagram;
- there is one owner for each of recording, provider execution, and local data;
- focused tests cover user states and cancellation races without duplicating
  every internal transition.

Expected direction:

- foreground Voice totals approximately 7,000-9,000 production lines;
- consent totals approximately 1,000-1,500 production lines.

## R5 — Compact History UI And App Stabilization

Goal: finish every visible containing-app destination.

Tasks:

- replace the placeholder with newest-first accepted text rows;
- add detail, Copy, Share, Delete, and confirmed Clear All;
- expose storage warnings without turning a completed dictation into failure;
- add the default-on `Save History` disclosure and confirmed
  disable-and-clear control;
- keep the existing Usage Estimate route as-is, smoke-test it, and add no new
  Usage work during V1.1;
- implement the D0-approved Full Access and App Group explanation in Setup and
  Privacy; remove any old claim that History is absent;
- verify Voice, Library, History, and Settings on compact iPhone;
- regression-check the existing iPad containing-app shell as best-effort
  compatibility, without claiming signed-iPad V1.1 qualification;
- verify Dynamic Type, VoiceOver labels, dark appearance, and empty/error
  states.

Exit:

- every Release destination performs a real user task;
- no hidden failed-row or retry-audio control remains;
- the containing app is ready for keyboard integration.

## R6 — Production Keyboard

Goal: replace the Phase-0 probe with one usable `en-US` keyboard.

### R6.1 Typing Engine

- letters, numbers, and symbols;
- Shift and Caps Lock;
- Delete repeat;
- Space, Return, `123`, symbols, and Globe;
- field-aware Return and basic auto-capitalization;
- double-space period;
- long-press Space cursor movement;
- key callouts and touch-target correction;
- light/dark appearance, haptics preference, and VoiceOver.

Ordinary typing has no network, provider, Keychain, or Full Access dependency.

### R6.2 Production Result Snapshot

- publish the accepted Latest Result from production app code;
- version, validate, and expire the minimal App Group snapshot;
- expose only accepted text and non-sensitive identifiers/timestamps;
- make one tap perform exactly one insert, suppress re-entrant handling, and
  allow another insertion only after another explicit tap;
- never insert on refresh, host change, relaunch, or app return;
- remove the DEBUG practice-only publisher after the real path passes.

### R6.3 Voice Action Bar

- add a dedicated microphone control;
- implement only the D0-selected action;
- never show `Listening` without containing-app recording ownership;
- preserve long-press Space cursor behavior;
- keep clear unavailable/setup/fallback states.

Exit:

- the keyboard is usable for normal typing;
- its voice action is honest and physically verified;
- each explicit tap inserts once, a later explicit tap may insert again, and no
  lifecycle event inserts automatically;
- the extension remains dependency- and secret-isolated.

## R7 — V1.1 Qualification

Automated and simulator:

- macOS build/tests appropriate to changed shared behavior;
- strict owning-package tests;
- iOS Debug and Release builds;
- embedded extension plist, entitlements, signature, and dependency isolation;
- Voice -> Latest -> History integration with fakes;
- one Pending relaunch Retry/Discard;
- complete navigation without placeholders;
- keyboard engine and bridge expiry tests;
- `git diff --check`.

Signed physical iPhone:

- Notes, Messages, Mail, Safari, and two third-party hosts;
- Full Access off/on;
- typing modes, Globe, cursor movement, Delete repeat, Return traits;
- secure, phone-pad, and rejected-keyboard fields;
- voice handoff, manual return, explicit Insert, expiry, and force quit;
- foreground microphone interruptions and route changes;
- Latest/Pending persistence, Keychain, and Data Protection;
- VoiceOver and large Dynamic Type smoke;
- memory, battery, and thermal observation for the actual foreground flow.

With explicit user authorization and a configured provider key, one manual
Standard-mode smoke covers physical microphone -> real OpenAI success ->
configured text rules -> Latest -> History -> manual return -> Insert. This is
operator evidence: automated agents do not enter the key or invoke live-provider
tooling without the explicit request. Translation remains a separate optional
live smoke because its composition is covered with fakes.

Exit:

- no open P0-P8 milestone is used to qualify V1.1;
- the V1.1 spec has requirement-by-requirement evidence;
- status may be `engineering complete, awaiting physical qualification` when
  code is green and D0 was positive but the full R7 device pass is incomplete;
- `release complete` requires the signed physical-iPhone pass.

## Explicitly Deferred

- failed-attempt History and retry audio;
- accepted audio playback and Recording Cache;
- background Quick Session and Full Access command bridge;
- predictions and advanced autocorrection;
- second typing locale;
- production iPad floating keyboard and Stage Manager;
- hardware-keyboard trigger, App Intent, and Live Activity;
- diagnostics export, cloud sync, analytics, profiles, and modes.

Deferred work is not silently started. It needs a short spec tied to observed
V1.1 use, not restoration of the old P0-P8 roadmap.

## Completion Dashboard

| Milestone | Status |
| --- | --- |
| R0 Scope reset and stable baseline | Completed 2026-07-13 |
| D0 Immediate signed keyboard gate | Not started |
| R1 Detach dormant History | Not started |
| R2 Compact persistence | Not started |
| R3 Delete legacy History and reduce tests | Not started |
| R4 Simplify Voice and consent | Not started |
| R5 Compact History UI | Not started |
| R6 Production keyboard | Not started |
| R7 V1.1 qualification | Not started |
