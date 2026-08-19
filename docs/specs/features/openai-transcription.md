# OpenAI Transcription

- Node type: hybrid
- Contract ID: `holdtype.shared.openai-transcription`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; iOS scope governed by current iOS contracts
- Contract revision: `holdtype.shared.openai-transcription@1`
- Read when: OpenAI file transcription, request transport, prompt, response, timeout, recovery, or provider privacy is in scope.
- Do not read when: only capture, output insertion, or a downstream text transform is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

HoldType sends bounded completed recordings to OpenAI's file transcription
endpoint and turns accepted non-empty JSON `text` into app text. It owns model,
language, prompt/dictionary context, file-backed multipart transport, response,
timeout/cancellation, recovery classification, usage handoff, and redaction.

## Non-goals

- Realtime streaming, translation endpoint, diarization, speaker labels,
  timestamps, subtitles, background-session continuation, provider abstraction,
  analytics audio retention, or live API calls in normal tests/automation.
- Auto-learning dictionary edits, snippets, expansion, or cloud dictionary sync.

## Children

- [Request settings and audio validation](openai-transcription/request-settings-and-audio.md)
- [Prompt, dictionary, and nearby context](openai-transcription/prompt-and-dictionary.md)
- [Response and downstream handoffs](openai-transcription/response-and-handoffs.md)
- [Failure recovery presentation](openai-transcription/failure-recovery.md)
- [Runtime prompt composition](openai-transcription/runtime-prompt-composition.md)
- [Runtime request and iOS reader](openai-transcription/runtime-request-and-ios-reader.md)
- [Multipart scratch and transport](openai-transcription/multipart-and-transport.md)
- [Scratch orphan maintenance](openai-transcription/scratch-maintenance.md)
- [Privacy and recovery ownership](openai-transcription/privacy-and-recovery.md)
- [Timeout, retry, and errors](openai-transcription/timeout-retry-and-errors.md)
- [State, verification, and evidence](openai-transcription/state-verification-and-evidence.md)

## Shared invariants

- Missing/inaccessible credentials block before provider contact; provider code
  receives a resolved transient credential and never reads Keychain.
- Audio is locally validated and durably recovery-owned before provider work.
- Every request is bounded, cancellation reaches the actual transport, and late
  completion cannot accept text.
- Secrets, audio, prompts/context/dictionary, transcript, payload, response, and
  local paths never appear in default logs.
- No silent retry; ambiguous post-dispatch outcomes remain fail-closed.

## Downstream boundaries

Correction, post-transcription actions, output, usage estimate, History, emoji
commands, and recording cache remain independently governed by their legacy
paths. This contract supplies only the specific accepted values they consume.
