# Dev Vlogs Autonomous Delivery Plan

Status: approved for execution by the user on 2026-08-11.

Pinned product contract: [`DV-ACTIVE-5`](specs/features/dev-vlogs.md).

Coordination state: [`docs/dev-vlogs-execution-registry.md`](dev-vlogs-execution-registry.md).

This plan completes the remaining Dev Vlogs product with minimal synchronous
operator involvement. It supersedes the earlier proposal that treated each
hardware observation as a separate user-assisted checkpoint. The user will
connect an iPhone or another selected camera; Codex owns implementation,
synthetic work sessions, bounded capture attempts, verification, repair, and
cleanup until a genuine external-authority boundary is reached.

## 1. Outcome

Deliver a local macOS Dev Vlogs workflow in which:

1. an eligible ordinary HoldType dictation may record the selected camera;
2. the vlog branch reuses the same finalized dictation audio under a bounded
   read lease and never opens a second microphone owner;
3. one dictation creates zero or one truthful, playable local source clip;
4. clips are organized and reviewed by day and trigger app;
5. the user can select one day and All Applications or one application, then
   create one publication-ready local video from every remaining clip in that
   scope;
6. the resulting artifact can be played, revealed in Finder, or passed to the
   macOS Share surface;
7. direct social-network publication and social-format transforms remain
   future work.

The concrete completion result is a real, release-path local workflow, not a
Debug harness, model, registry, or collection of tests.

## 2. Product And Design Brief

### 2.1 Window structure

The accepted Settings-quality Dev Vlogs window keeps its native SwiftUI
sidebar/detail structure. Its complete product sequence becomes:

1. Overview
2. Capture
3. Applications
4. Storage
5. Publish

`Publish` is the final primary section. A separate user-facing `Builds`
section is unnecessary: a build recipe remains an internal durable product
entity, while the user-facing workflow is preparing one artifact for
publication. Camera recovery remains in Capture; readiness remains in
Overview. No placeholder Permissions or social-account section is added.

### 2.2 Publish meaning

V1 `Publish` means local artifact preparation, not direct remote publication.
The user can:

- choose a recorded local day;
- choose All Applications or one application present that day;
- open that exact day or application folder in Finder and review clips with
  Quick Look;
- delete unwanted source clips only in Finder;
- rely on automatic disk refresh or request an explicit Refresh;
- create one video;
- monitor progress or cancel;
- play, reveal, or share a completed artifact.

The only initial output policy is `Original`:

- no HoldType-imposed source resolution reduction;
- no nominal-frame-rate reduction;
- no hidden source-video re-encode;
- no Twitter, Facebook, square, portrait, caption, or other social presets;
- no provider account, credential, upload, or public-post action.

These are Build invariants, not a pre-build policy or disclosure block in the
Publish interface.

If the selected scope's remaining clips cannot be assembled through the
accepted compatible passthrough path, V1 fails the Build truthfully without an
output. It does not silently transcode. This plan treats that as the recommended
resolution of the previous `DV-BUILD-6` fork, subject to the contract delta
recorded before its dependent Phase 4 implementation.

### 2.3 Visual basis

The visual target is the already accepted Dev Vlogs/Settings design language:

- native macOS `NavigationSplitView` and source-list sidebar;
- semantic Forms and grouped Settings-density content;
- SF Symbols and system-adaptive Light/Dark colors;
- status first, secondary paths and metadata second;
- one obvious primary action per state;
- complete empty, ready, progress, failed, and completed states;
- no technical placeholders or invented future controls.

All visible content and interaction remain SwiftUI.

## 3. Contract Change Envelope

- Task: complete the Release-path Dev Vlogs workflow from accepted setup
  through local Publish artifact creation.
- Change mode: scoped `evolve` under `DV-ACTIVE-5`; `reconcile` only for the
  accepted `Builds` to `Publish` information-architecture change and the
  selected no-transcode incompatible-source policy.
- User-authorized outcome: autonomous completion with a connected camera and
  minimal operator participation, explicitly approved on 2026-08-11.
- Authorized domains: Dev Vlogs UI, enablement, app eligibility, preferred
  camera capture, destination resolution, capture lifecycle, bounded shared
  audio lease, vlog archive, Finder-owned daily source review, compatible local
  Build, Publish artifact, Reveal, and macOS Share.
- Authorized clauses: `DV-APP-*`, `DV-CAPTURE-*`, `DV-CAMERA-*`,
  `DV-STORAGE-*`, `DV-FOLDER-*`, `DV-REVIEW-*`, `DV-BUILD-*`, `DV-SHARE-1`,
  `DV-UI-*`, `DV-AUDIO-LEASE-*`, `DV-DURABILITY-*`, and `DV-PRIVACY-*` only
  where they directly govern the local Dev Vlogs workflow.
- Protected adjacent domains: ordinary dictation, transcription, correction,
  translation, accepted output, Transcript History, Recording Cache, shared
  Settings and Keychain, diagnostics, updates, unrelated menu commands, every
  iOS target, website/marketing, and direct publication.
- Stability baseline: existing macOS HoldType behavior is released and
  protected; accepted Phase 1 Dev Vlogs setup/UI remains preserved.
- Required evidence: focused fake-backed behavior tests, structure/build
  gates, one proportional review per shipping iteration, bounded real camera
  and media evidence where the capability requires it, and Computer Use for
  changed visible workflows.
- Allowed specification delta: replace the future user-facing Builds section
  with Publish, define Publish as local artifact preparation, record the V1
  incompatible-source no-output policy, and update acceptance mapping.
- Forbidden specification delta: second microphone ownership, hidden capture,
  silent camera or destination fallback, guessed storage thresholds,
  automatic source deletion, source-video downsample/re-encode, direct social
  publication, new CLI/API, or any adjacent product change.
- Material decisions still requiring the user: none inside the approved V1
  plan unless new evidence proves an unavoidable product fork outside this
  envelope.
- Contract epoch: `DV-ACTIVE-5` for the Finder-owned day/application Publish
  workflow.

## 4. Operator-Minimization Contract

### 4.1 Operator contribution

The expected operator contribution is one physical preparation step:

- connect the iPhone or selected camera and leave the Mac unlocked and the
  device available during the bounded hardware phase.

No repeated status confirmations, shell commands, log inspection, manual
fixture creation, or routine QA actions are expected from the operator.

### 4.2 Autonomous actions

Within the approved scope Codex may:

- build and launch isolated task-owned HoldType products;
- use Computer Use to operate the visible app;
- select the connected camera and configured destination;
- create harmless synthetic work in a local test application;
- generate a local deterministic spoken marker for short recording sessions;
- start and stop bounded camera/dictation attempts;
- create task-labelled local vlog clips and Publish artifacts;
- inspect only task-owned media and metadata required for validation;
- retain final demonstration artifacts and remove exact run-owned temporary
  fixtures after identity checks;
- rerun focused deterministic tests and bounded product QA under this plan.

Normal automation does not call OpenAI or read live Keychain credentials.
Dictation independence is verified through existing deterministic provider
seams; real hardware is used for camera/audio/media behavior.

### 4.3 External-authority fallback

If macOS or the device requires an action that cannot be completed safely or
is disallowed by the active tool confirmation policy, Codex must:

1. finish every independent implementation and deterministic verification
   step;
2. avoid repeated prompts or improvised system changes;
3. retain a truthful blocked sub-result;
4. return one consolidated operator action at the end.

No TCC database edit, password entry, `Always Allow`, destructive external
storage operation, or public Share completion is authorized.

## 5. Economic And Orchestration Contract

The default milestone split is:

- 60% shipping implementation;
- 25% verification, review, and runtime QA;
- 15% discovery, diagnostics, tooling, specification, and coordination.

Execution uses one implementation stream at a time. Independent review begins
only after a release-path capability exists. Parallel support fan-out and
speculative explorers are forbidden.

For each iteration:

- one implementation receipt;
- one proportional review;
- at most one focused repair/re-review cycle;
- no new Debug subsystem;
- no production hardening of temporary diagnostics;
- no second repair cycle without a delivery-and-cost reassessment and explicit
  user approval, except for an unresolved demonstrated data-loss, privacy,
  security, irreversible-action, or released-compatibility risk.

Progress reports separate shipping product paths and capability from tests,
diagnostics, evidence, documentation, and coordination cost.

## 6. Iteration 1 — Complete Publish UI

Expected effort: 1.5–2.5 hours.

Work classification: `shipping_product`.

### Shipping outcome

- Add Publish as the final sidebar section.
- Implement a polished Settings-quality screen with Source Day, day summary,
  Finder/Refresh, the primary Create Video action, Build Progress, and Result
  groups, without a pre-build Output/policy block.
- Provide truthful product states:
  - no recordings;
  - empty selected day;
  - populated day;
  - invalid or missing sources;
  - ready to build;
  - building;
  - cancelled;
  - failed;
  - completed artifact.
- Expose `Create Video`, Cancel, Play, Reveal, and Share only when their
  owning capability/state exists.
- Do not display output-policy or future social-profile controls.
- Keep the empty shipping state truthful until real archive data exists.

### Supporting work

- Record the approved IA/Publish contract delta before implementation.
- Add deterministic view/state tests and previews using realistic local fake
  data.
- Run structure, focused tests, macOS build, and Computer Use against the real
  empty/reachable Publish section.

### Completion

The Release app exposes Publish as the final section, the screen matches the
accepted Dev Vlogs quality level, all controls reflect truthful state, and no
media operation or future-provider behavior is falsely implied.

### Stop conditions

- a new product decision outside the approved brief is required;
- implementation requires a new AppKit visible surface;
- the work expands into a clip editor or media-engine implementation;
- runtime QA needs an unavailable system authorization after a bounded
  attempt; record a residual rather than expanding tooling.

## 7. Iteration 2 — Autonomous One-Clip Capture

Expected effort: 6–8 hours if the entry gate passes.

Work classification: `shipping_product`, with one bounded diagnostic entry
gate.

### Entry gate

- Review the already-written W10 closed diagnostic mapping.
- Add no new observer, harness, or Debug architecture.
- Perform at most one short Continuity preservation attempt.
- If strict negotiated-video preservation succeeds, proceed immediately to
  shipping implementation.
- If it fails or the existing mapping is invalid, stop the iteration within
  the bounded gate and report the exact residual. Do not retry or expand Phase
  0B.

Entry-gate effort limit: 45 minutes.

### Shipping outcome

- Freeze trigger app, app policy, preferred camera, destination, and attempt
  identity at dictation start.
- Resolve only the remembered camera; never substitute another camera.
- Start a bounded camera-only capture branch while ordinary dictation retains
  the only microphone owner.
- Obtain one bounded read lease on the finalized authoritative dictation audio
  artifact.
- Align and mux camera video with that audio through a proven video-passthrough
  path.
- Validate playable video and audio before marking the clip Ready.
- Publish zero or one source clip under the exact day/app archive owner.
- Persist minimal non-sensitive clip metadata with stable identity.
- Expose Preparing, Capturing, Finalizing, Saved, Skipped, and Failed states in
  the accepted Dev Vlogs surfaces.
- Release the audio lease and all active ownership on every success, skip,
  cancel, timeout, failure, and teardown path.

### Autonomous runtime scenario

1. Open a harmless local test application.
2. Create bounded synthetic work activity.
3. Start an eligible normal HoldType dictation.
4. Play a deterministic local spoken marker.
5. Stop the dictation.
6. Verify one source clip, playable `1V/1A`, expected audio ownership,
   negotiated video preservation, and normal dictation state.
7. Repeat only once after a concrete implementation repair when the first
   product attempt establishes that repair dependency.

The complete iteration allows at most:

- one entry-gate hardware attempt;
- one final product attempt;
- one post-repair product confirmation.

### Focused evidence

- eligible and ineligible apps;
- unknown trigger app;
- unavailable/busy/disconnected preferred camera;
- missing/unwritable destination with no fallback;
- exact-once stop/finalization under racing terminal paths;
- one microphone owner;
- lease release on every terminal route;
- vlog failure leaves dictation/provider/output behavior unchanged;
- playable `1V/1A` validation and no false Ready;
- no transcript, prompt, credential, media payload, app content, or full local
  path in default logs.

### Completion

One eligible ordinary dictation creates exactly one real playable local clip
with the same speech audio and preserved negotiated video, while every vlog
failure leaves ordinary dictation usable and unchanged.

### Stop conditions

- the entry gate fails;
- a second microphone owner appears necessary;
- source-video encoding/downsample appears necessary;
- the existing dictation contract would need semantic weakening;
- a new Debug subsystem is proposed;
- the iteration exceeds eight hours without a working release-path clip.

## 8. Iteration 3 — Simple Finder-Owned Daily Publish

Expected effort: 6–8 hours.

Work classification: `shipping_product`.

### Publish outcome

- Show real archive days newest first, offer All Applications plus applications
  present that day, and summarize the selected scope.
- Open the exact selected day or application folder in Finder for source
  review and deletion.
- Observe the selected scope while Publish is visible and provide Refresh.
- Reconstruct every remaining valid clip in that scope at action time and order
  by recorded timestamp with stable ID tie-breaking.
- Save the build recipe before rendering.
- Assemble compatible clips into one immutable local video without
  source-video re-encoding or source overwrite.
- Provide bounded progress, cancel, failure, and retry.
- Validate the completed artifact before Play, Reveal, and Share become
  available.
- Preserve source clips and prior outputs on cancellation or failure.

### Completion

The user can record several clips, review/remove them in the selected day or
application folder using Finder, see Publish refresh from disk, and create one
playable original-quality local artifact from every remaining clip in that
scope.

### Stop conditions

- compatible passthrough cannot produce the selected output;
- implementation proposes automatic deletion or source overwrite;
- a remote provider/account or social-format transform is introduced;
- selected day/application-scope reconstruction or observation cannot be made
  truthful.

## 9. Iteration 4 — Autonomous Final Acceptance

Expected effort: 1.5–2.5 hours.

Work classification: `verification` after the shipping product exists.

### Scenario

1. Record several short eligible dictation/vlog attempts.
2. Verify zero-or-one clip identity for each attempt.
3. Exercise more than one app/day grouping through deterministic setup where
   practical.
4. Select a day in Publish and open its exact folder in Finder.
5. Remove one exact task-owned source through Finder/CLI and verify automatic
   or explicit Refresh reconstructs the day without recreation.
6. Create one Publish artifact from every remaining clip in timestamp order.
7. Play and reveal the result.
8. Open the macOS Share surface without completing an external share.
9. Exercise a vlog failure and prove ordinary dictation remains usable.
10. Clean exact run-owned failed fixtures and preserve the final labelled
    demonstration source/output artifacts for user inspection.

### Final evidence

- focused domain and integration tests;
- structure and diff hygiene;
- macOS Debug and Release build evidence;
- signed entitlement/purpose-string verification where applicable;
- Computer Use for changed visible workflows;
- bounded real camera/media acceptance;
- exact process/temp/root cleanup;
- one final proportional review of the integrated product.

### Completion

The goal completes only when the real local camera-to-clip-to-Publish workflow
exists, its product acceptance is terminal, protected ordinary dictation
behavior remains accepted, and any residual does not hide a missing claimed
capability.

## 10. Explicitly Out Of Scope

- direct Twitter, Facebook, YouTube, or other provider publication;
- provider credentials, accounts, OAuth, uploads, or publication status;
- social aspect-ratio/resolution profiles;
- captions, transcript search, title cards, transitions, trim, or timeline;
- automatic highlights or automatic retention/deletion;
- multiple simultaneous cameras or silent camera fallback;
- CLI or automation API;
- iOS behavior;
- guessed numeric low-space thresholds;
- unrelated product cleanup or refactors.

## 11. Goal-Level Stop And Reporting Rules

The goal pauses and returns to the user only when:

- an external permission/trust action cannot be automated after all
  independent work completes;
- a real product fork outside this approved plan is proven;
- continuation would weaken dictation, privacy, durability, or source-quality
  contracts;
- a second substantial repair/re-review cycle is required;
- an iteration crosses its economic bound without the named shipping outcome;
- a destructive action outside exact run-owned temporary fixtures is needed.

Otherwise execution proceeds across the four iterations without intermediate
operator approval. Each iteration ends in a scoped master checkpoint and a
compact progress receipt before the next dependency-ready iteration begins.
