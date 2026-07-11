# iOS Failed History Retry Provider Outcomes QA

Date: 2026-07-12
Milestone: P2 C4.4B provider outcomes and durable Retry failure

## Scope

- Freeze the current Transcription prompt composition without Nearby Text,
  optional correction, one local post-processing configuration, optional
  Translation, credential eligibility, and Keep Latest Result before Retry
  reservation.
- Run descriptor-backed Transcription outside the root operation gate with only
  the resolved model, resolved language, frozen prompt composition, exact Usage
  identity, and bounded audio reader crossing the provider boundary.
- Record one idempotent, non-authoritative Usage attempt immediately after a
  non-empty Transcription result and before correction or Translation.
- Apply optional remote correction fail-open, then local cleanup, emoji
  commands, and replacement rules exactly once. Translation consumes only that
  processed transient text and remains strict.
- Map terminal Transcription and Translation outcomes through the complete
  payload-free durable category table while preserving the prior category and
  stage for unmappable outcomes.
- Retire stage authority on timeout or cancellation, cancel and drain only the
  bounded provider adapter, and reject any noncooperative lower-layer late
  completion.
- Clear only the exact `providerDispatched` operation after a durable failure,
  advance `updatedAt`, preserve retry count and audio ownership, and retain the
  exact completion claim through Store uncertainty.
- Keep successful provider text process-local for C4.4C. If that output is
  dropped before acceptance claims it, return the exact row to retryable state
  without persisting or logging the text.

C4.4C still owns `acceptingOutput`, the failed/delivery interlock, normal
accepted-output publication, terminal History provenance, and success cleanup.
C4.4D/C4.5 still own process-loss integration and the public containing-app
factory backed by fresh Keychain/setup resolution.

## Automated Evidence

- Focused strict Retry outcome suites passed: 31 tests in 3 suites.
- `swift test --package-path Packages/HoldTypePersistence --no-parallel
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 818 tests in 43 suites.
- The matching strict-concurrency, warnings-as-errors release package build
  passed.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test -quiet`
  - Result: 441 passed, 0 failed, 0 skipped.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' build
  -quiet` and the matching test action passed on iPhone 16 Pro running iOS
  18.6.
  - Test result: 1,181 passed, 0 failed, 0 skipped.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: the C4.4B pipeline, provider requests/outcomes, exact failure
    capabilities, terminal owner, and accepted provider output remain absent
    from the public graph.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: only expected system linkage; no Domain, Persistence, IOSCore,
    OpenAI, PendingRecording, failed History, Retry, Usage, provider, or
    Keychain linkage, symbol, or string entered the keyboard.
- `git diff --check`
  - Result: passed.

No verification command contacted OpenAI or used a live API key.

## Verified Provider Pipeline

- Setup rejects missing credential eligibility, invalid effective
  Transcription/Translation routes, and Nearby Text before the first durable
  write. A dormant invalid correction model does not block Retry while remote
  correction is disabled.
- The Transcription adapter receives no full `TranscriptionConfiguration` or
  raw freeform prompt. Translation receives the portable
  `TextTranslationRequest`, which retains only the accepted source text,
  Translation configuration, and resolved source-language code.
- A non-empty Transcription result creates one Usage attempt under the retry's
  preallocated `transcriptionID`. Duplicate or failed Usage persistence cannot
  change provider output, failed History, Translation, or replay behavior.
- Correction failure, timeout, empty output, unsafe-length output, and
  provider-reported cancellation all preserve the accepted transcription.
  Local post-processing falls back to the corrected pre-cleanup text and runs
  exactly once.
- Translation sees only the processed transient transcription. Its final
  optional local pass normalizes plain typography only; it does not rerun
  correction, emoji commands, or replacement rules.

## Verified Timeout And Failure Contract

- Each provider stage has an explicit timeout. Deadline or outer cancellation
  retires the stage race, cancels the adapter Task, and waits for that adapter's
  bounded terminal acknowledgement before the outer live owner can clear.
- Test adapters separate their bounded cancellation response from a deliberately
  noncooperative lower-layer task. The pipeline completes only after the adapter
  drains, while the released lower-layer result remains ignored afterward.
- Credential, network, timeout, rate-limit, provider, invalid-response, empty,
  and Transcription echo outcomes map to the exact stable categories. Provider
  status codes and payloads do not exist at the Store boundary.
- Echo is stage-aware: dictionary/context echo can map only at Transcription;
  a defensive Translation echo outcome is unmappable and preserves the prior
  durable category and stage.
- Invalid recording/request/route, oversized metadata, provider-reported
  terminal cancellation, and unknown outcomes clear only the exact Retry
  operation and preserve the prior failure fields.

## Verified Completion Ownership And Privacy

- Provider completion and cancellation remain mutually exclusive exact
  terminal epochs. A durable failure consumes only the matching retained
  completion claim and active root lease.
- Source- and outcome-visible Store uncertainty reuse the same frozen failure
  authorization. Retry count, audio/configuration identity, and terminal epoch
  never advance again during reconciliation.
- The root strongly retains the exact terminal owner. A later Retry entrypoint
  retriggers only retained local failure work and never replays provider work.
- Pipeline, provider request/outcome, completion, accepted output, audio reader,
  and failure capabilities use fixed redacted descriptions and mirrors. Canary
  coverage proves provider text, credential-like data, repository paths, and
  protected-audio paths do not appear in ordinary reflection.
- Raw text, prompts, dictionary contents, replacement rules, credentials,
  provider payloads, audio, paths, status codes, and Store capabilities remain
  outside durable failed rows, App Group state, and the keyboard target.

## Independent Review Fixes

Three independent read-only reviews found and verified fixes for:

- a full Transcription configuration and raw prompt initially crossing the
  provider request boundary;
- Translation initially receiving a full Transcription configuration instead
  of the narrow portable translation request;
- local post-processing initially falling back to raw rather than successfully
  corrected text;
- echo mapping initially lacking the active pipeline stage;
- a dormant invalid correction model initially blocking Retry while correction
  was disabled;
- timeout/cancellation initially releasing the outer owner before the bounded
  adapter had drained, followed by an intermediate unbounded fake contract;
- default pipeline reflection initially exposing provider and Usage adapter
  storage;
- missing direct canary coverage for credential-like values, repository paths,
  protected-audio paths, corrected fallback, Translation echo, and late
  lower-layer results.

The final repeated spec, concurrency/architecture, and Apple/privacy reviews
reported no remaining P0 or P1 finding.

## Verdict

P2 C4.4B provider outcomes and durable Retry failure: passed for focused and
full strict package tests, release build, macOS regression, iOS simulator,
public API isolation, keyboard binary isolation, exact Store uncertainty,
bounded adapter cancellation, late-result rejection, payload redaction, and
independent review.

The next checkpoint is C4.4C: commit `acceptingOutput`, freeze and protect the
exact predecessor delivery, publish normal accepted output under the shared
failed/delivery interlock, seal terminal History provenance, and move the
successful failed row to its exact cleanup tombstone.
