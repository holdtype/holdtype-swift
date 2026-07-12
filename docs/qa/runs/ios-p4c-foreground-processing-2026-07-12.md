# iOS P4C Foreground Processing QA

Date: 2026-07-12
Milestone: P4C reader-based OpenAI and consent-gated foreground processing

## Scope

- Add a neutral reader-bound transcription request to `HoldTypeOpenAI` so the
  provider can consume exact protected audio bytes in bounded chunks without
  receiving a source URL, path, descriptor, `FileHandle`, or second path-based
  audio handoff. The existing transport may still create its own bounded,
  private multipart scratch artifact.
- Bind the protected one-shot Pending reader to that request only inside
  `HoldTypeIOSCore`: use the exact committed Pending audio, verify reader
  duration and byte-count metadata, forward the reader format and committed
  model/language, and compose the prompt from the frozen processing request.
- Implement one process-owned foreground processor for initial and explicit
  Retry dispatch through Transcription, optional correction, local processing,
  strict Translation, Usage handoff, exact Pending transitions, and P4B
  accepted-output persistence.
- Enforce the current provider-consent epoch and revision separately at launch
  and result consumption for Transcription, correction, and Translation.
- Never replay a provider automatically after result consumption. Local
  transition or app-only acceptance uncertainty retains provider-free work;
  cancellation or a terminal provider-stage failure targets exact Pending
  recovery. Confirmed `awaitingRecovery` permits only a later explicit Retry to
  start a fresh provider chain; failed local confirmation retains same-process
  recovery work.
- Add no microphone implementation, audio-session ownership, Voice UI,
  background mode, Quick Session, History row, App Group publication, keyboard
  provider dependency, or external-app insertion. Those foreground audio and
  presentation surfaces remain P4D.

## Automated Evidence

- Strict full `HoldTypeOpenAI` package tests with serialized execution,
  complete concurrency, and warnings as errors
  - Result: 118 passed in 8 suites.
- Strict full `HoldTypePersistence` package tests with serialized execution,
  complete concurrency, and warnings as errors
  - Result: 1,028 passed in 52 suites.
- Strict full `HoldTypeIOSCore` package tests with complete concurrency and
  warnings as errors
  - Result: 88 passed in 8 suites.
- Focused foreground-processor tests
  - Result: 19 passed.
- Containing-app composition tests on iPhone 16 Pro / iOS 18.6
  - Result: 6 passed.
- Full `HoldType-iOS` simulator regression with `HOLDTYPE_AUTOMATION=1` and
  `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip`
  - Result: 1,556 passed, 0 failed, 0 skipped on iPhone 16 Pro / iOS 18.6.
  - Result bundle:
    `/Users/eugenepotapenko/Library/Developer/Xcode/DerivedData/HoldType-aiagnlkblhltvacjmbtlpyjistgi/Logs/Test/Test-HoldType-iOS-2026.07.12_22-26-35-+0200.xcresult`.
- Full `HoldType` macOS regression with the same automation credential boundary
  - Result: 441 passed, 0 failed, 0 skipped on macOS 26.5.1.
  - Result bundle:
    `/Users/eugenepotapenko/Library/Developer/Xcode/DerivedData/HoldType-aiagnlkblhltvacjmbtlpyjistgi/Logs/Test/Test-HoldType-2026.07.12_22-13-41-+0200.xcresult`.
- Release package builds with complete concurrency and warnings as errors
  - `HoldTypeOpenAI`: passed.
  - `HoldTypeIOSCore`: passed.
  - `HoldTypePersistence`: passed.
- Release Xcode builds
  - Generic iOS Simulator `HoldType-iOS`: passed under
    `/tmp/holdtype-p4c-release-ios`.
  - macOS `HoldType`: passed under `/tmp/holdtype-p4c-release-macos`.
- `git diff --check`
  - Result: passed.

No verification contacted OpenAI, used a real API key, read or wrote live
Keychain data, requested microphone access, touched the clipboard, enabled
keyboard Full Access, or exercised a live provider transport.

## Reader And Provider Boundary

- `HoldTypeOpenAI` receives a neutral asynchronous byte reader plus explicit
  metadata. It neither imports Persistence nor learns the Pending storage
  location.
- The IOSCore transcription executor builds the provider request from one exact
  committed Pending owner. Reads are capped at 64 KiB and the handoff is
  one-shot: the retained request becomes unreadable after dispatch.
- Exact metadata mismatch or a lost reader handoff fails before provider launch.
  Initial and explicit Retry dispatch each require a fresh exact reader.
- A normalized non-empty `AcceptedTranscript` is created inside the
  consent-gated transcription result operation. No raw provider string escapes
  first and becomes accepted after consent has changed.
- Transcription, correction, and Translation use stage-specific launch and
  result capabilities. Credential rejection records the exact resolved runtime
  credential generation; non-authentication failures do not mark it rejected.

## Processing, Usage, And Recovery

- The pipeline order is Transcription, Usage handoff, exact Pending
  post-processing transition, optional fail-open correction, local
  emoji/dictionary/replacement processing, optional strict Translation, exact
  Pending output-delivery transition, and P4B acceptance.
- The processor makes one idempotent Usage handoff keyed by transcription ID
  immediately after a consent-consumed, normalized successful transcription.
  Later stages and local recovery do not invoke it again. A local Usage
  persistence failure is non-fatal and has no P4 retry queue.
- A successful correction replaces the transcript before local processing. An
  empty, unsafe, unavailable, or failed correction keeps the original accepted
  transcript. Translation is strict: failure never accepts untranslated text.
- A retry of retained same-process post-provider local work is provider-free.
  Failed or uncertain local transitions reload exact Pending truth and adopt a
  visible destination only after same-phase durability confirmation. After the
  exact attempt has instead reached durable `awaitingRecovery`, a later
  explicit Retry intentionally starts a fresh provider chain.
- Ambiguous, missing, replaced, or mismatched local observations preserve the
  retained provider-free work instead of launching a provider or guessing that
  a transition succeeded.
- Cancellation after consumed Transcription but before final local delivery
  discards the in-memory transcript and targets `awaitingRecovery`; failed
  confirmation retains same-process recovery work without automatic provider
  replay. Cancellation during a retained output-delivery or acceptance
  checkpoint preserves that provider-free checkpoint. Cancellation before
  consumption does not manufacture accepted output.
- P4B reconciliation checks complete accepted bytes, output intent, attempt,
  and app-only destination identity. UUID equality alone is insufficient, and
  Keep Latest revocation remains one-way.

## Process Ownership And Composition

- `IOSForegroundVoicePersistenceOwner` retains the exact canonical Pending actor
  and matching P4B facade for the containing-app process lifetime.
- `IOSContainingAppComposition` retains one consent coordinator, Persistence
  owner, Usage repository, and foreground processor. Multi-scene callers share
  those identities rather than reconstructing scene-local processing graphs.
- Missing production credential coordination leaves the composition explicitly
  `credentialUnavailable` while preserving the local persistence and recovery
  owners and omitting the foreground processor. It does not substitute a test
  credential or silently widen authority.
- Concurrent process requests remain admission-gated. Local recovery state is
  reported only when the processor is idle with retained same-process recovery
  work.

## Privacy And Keyboard Isolation

- The public processing request, resolution, and processor plus the internal
  transcription executor expose redacted descriptions and empty mirrors.
  Canary tests cover a credential, prompt, dictionary content, transcript, and
  private path. The new P4C code emits no product logs.
- The Release `HoldTypeKeyboard` target still has no target, package-product, or
  framework dependency. Its compile list contains only
  `KeyboardViewController.swift` and `KeyboardBridge.swift`; its link list
  contains only their two object files.
- Release inspection found only system Foundation/UIKit/Swift dependencies and
  no OpenAI, IOSCore, Persistence, provider, credential, Keychain, network,
  microphone, Speech, or audio symbols or strings. `RequestsOpenAccess` remains
  false, and the source entitlement remains only the existing App Group.
- The embedded simulator Release extension passes strict code-signature
  verification. P4C publishes no provider, consent, Pending, accepted-output,
  or Usage data to the App Group. Standalone and embedded executables are
  byte-identical with SHA-256
  `99a28e785f009df4966aac61f639a854bdf260075a8dbe3ab22a9063be023d4a`.

## Independent Review

Independent review was repeated after the reader binding, consent-consumption,
cancellation, usage, local-reconciliation, and composition tests landed. It
found no remaining blocker or P1 issue. The final review specifically covered
provider replay, consumed-result cancellation, local commit uncertainty,
acceptance identity, process owner lifetime, redaction, and extension isolation.

## Assessment

P4C passes. HoldType now has a consent-gated, reader-bound, app-only foreground
processing pipeline with exactly-once Usage handoff and same-process
provider-free local recovery. P4D is next: implement the bounded foreground
audio session and recorder, bind the shared process Voice owner and native Voice
UI, and collect simulator runtime evidence without adding background audio,
Quick Session, App Group publication, or keyboard provider dependencies.
