# iOS P4 Foreground Voice Contract Freeze QA

Date: 2026-07-12
Milestone: P4A spec-first foreground voice, consent, recovery, and output freeze

## Scope

- Freeze the user-visible and durable contract for the P4 app-only foreground
  voice vertical slice before Swift implementation.
- Resolve how one multi-scene voice owner performs setup, microphone capture,
  provider work, local processing, cancellation, recovery, and accepted output.
- Preserve the existing strict PendingRecording and accepted-delivery wire
  formats while adding a named no-History P4 transaction path.
- Freeze a strict provider-consent record and stage/result authorization gate.
- Keep P4 free of background audio, Quick Session, App Group publication,
  keyboard commands, History rows, Recording Cache, and external-app insertion.

## Frozen Product Contract

- One process-owned voice owner is shared by every iPhone and iPad scene. Start
  admission, prompt ownership, cancellation, Retry, Discard, and late callbacks
  are identity-bound and cannot create parallel attempts.
- Foreground preflight is ordered: process admission, active scene, canonical
  storage/Pending truth, Settings and Library snapshot, intent validation,
  current consent, credential, microphone authorization, then playback handoff
  and recording-session activation.
- Aggregate scene loss, interruption, input-route change/loss, microphone
  revocation, and media-services reset stop retained capture visibly. A valid
  partial becomes explicit Pending recovery; no lifecycle event uploads or
  resumes automatically.
- The current P4 provider disclosure is version `1`. Consent uses a strict
  app-private epoch/revision record with compare-and-swap, required directory
  durability, stale-Accept rejection, withdrawal-first gate closure, and
  dispatch/result revalidation for Transcription, Correction, and Translation.
- P4 OpenAI transcription consumes the one-shot protected Pending reader
  directly in chunks no larger than 64 KiB. No absolute source URL, path,
  `FileHandle`, descriptor, or equivalent materialized source file crosses the
  Persistence boundary.
- A completed result advances Pending to `outputDelivery`, commits or atomically
  replaces one generation-0 accepted-delivery record with
  `historyWrite: null`, retires exact Pending audio and journal ownership, and
  only then presents `resultReady`.
- Any unresolved delivery commit, replacement, destination proof, audio removal,
  or journal retirement remains `Saving Result`. Retry resumes the last local
  checkpoint and never repeats provider work. Provider Retry becomes possible
  only after exact no-destination proof and an explicit transition back to
  Pending recovery.
- Voice presents selectable final text with explicit Copy, text-only Share, Use
  in Practice, and confirmed Clear. Clear separates pre-tombstone failure,
  logical tombstone success, and later physical cleanup.

## Review Evidence

- Product-contract review found and closed:
  - the universal History/publication sequence that initially contradicted the
    P4 generation-0 no-History branch;
  - the missing same-process accepted-output recovery path;
  - the Clear logical-versus-physical boundary;
  - the durable Pending check ordering;
  - the `Saving Result` gap after a durable destination but before Pending
    retirement;
  - the missing current disclosure version and truthful P4 retention copy.
- Apple/privacy review found and closed:
  - stale cross-scene Accept after Withdrawal;
  - aggregate scene loss during post-activation arming;
  - provider-consent directory durability and commit-uncertain reconciliation.
- Architecture review verified that the additions are implementable without
  changing the frozen Pending or accepted-delivery wire formats and without
  introducing a Persistence/OpenAI dependency cycle. The reader contract lives
  in OpenAI, Persistence supplies its bounded source, and IOSCore binds them.
- Final independent product, architecture, Apple-platform, and privacy reviews
  report no remaining P1/P2 finding.

## Verification

- `git diff --check`: passed.
- This checkpoint changes specs, the spec index, roadmap status, and this QA
  evidence only. It changes no Swift, Xcode target, entitlement, purpose string,
  privacy manifest, storage file, App Group byte, or keyboard executable.
- No live OpenAI call, API key, Keychain access, microphone request, clipboard
  operation, or Full Access behavior was used.

## Assessment

P4A passes. The foreground voice vertical slice now has one coherent contract
for UI state, consent, audio lifecycle, provider boundaries, crash recovery, and
app-only output. P4B is the next checkpoint: implement and verify the canonical
Persistence transaction for app-only accepted delivery, exact Pending
retirement, load/Clear, and `Saving Result` recovery.
