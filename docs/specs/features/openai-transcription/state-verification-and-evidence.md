# Transcription State, Verification, and Evidence

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.verification`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.verification@1`
- Read when: state/data routing, acceptance tests, external evidence, or unresolved decisions is in scope.
- Do not read when: only one selected request or transport responsibility is in scope.
- Maximum size: 100 physical lines.

## State and data routing

- Enter `transcribing` only after stop and uploadable file.
- Settings include model, language/custom code, prompt, dictionary, and Nearby Text enablement.
- Provider failures become product errors before views, with compact copy plus
  stable redacted operator category.
- Accept text only after parse, trim, and empty validation.
- Correction/action/output, usage, cache, and History receive only their stated
  narrow values; no provider response, credential, prompt/context/dictionary,
  transcript, or persistent local path leaks across boundaries.

## Verification

- Fakes cover credential categories, rate limit, timeout, network, bad settings,
  invalid/empty audio, server, empty text, echo rejection, parse, recovery,
  retry, compact errors, and redaction; never live OpenAI in normal automation.
- Inject clock/delay; prove cancellation returns before blocked loader/source/
  scratch/sync/`pread`, late cleanup safety, and independent request identity.
- Prove pinned bytes survive pathname replacement; independent streams replay
  completely; exact-origin 307/308 preserve trusted header/body while
  cross-origin and 301/302/303 receive neither.
- Exercise early EOF/read failure as typed local error and v1 marker/protection/
  publish failure as source-preserving operation-owned cleanup.
- Maintenance tests cover exact one-hour/24-hour ages, grammar/xattr, missing
  namespace, symlink/hardlink/directory/nested/source-name/replacement races,
  locks, idempotency, and 256-entry/32-removal/512-MiB/one-second boundaries.
- Verify macOS/iOS hook scheduling and no keyboard HoldTypeOpenAI dependency.
- Use fake Accessibility, usage store, transcription, and filesystem/cache.
- Real microphone/provider QA stays separate from normal automation.

## Evidence

- OpenAI Speech to Text guide, `https://developers.openai.com/api/docs/guides/speech-to-text`.
- `gpt-transcribe` model/pricing, `https://developers.openai.com/api/docs/models/gpt-transcribe`.
- Create transcription API, `https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create`.
- Apple streamed-upload API, `https://developer.apple.com/documentation/foundation/urlsession/uploadtask(withstreamedrequest:)`.
- OpenAI evidence was reviewed 2026-08-04; Apple evidence 2026-07-10.

## Unknowns

- Revalidate 60 seconds with real recordings; choose default model tradeoff;
  decide accepted custom-language code range, dictionary auto-learn, and whether
  Nearby Text should become default-on only after privacy/compatibility evidence.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared verification scope.
