# iOS Voice Provider Handoff

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.provider@1`
- Read when: provider dispatch, stage completion, usage, or History ownership matters.
- Do not read when: only recording routes matter.
- Maximum size: 100 physical lines.

Recording is recoverable/journaled before provider, which reads one-shot
descriptor source, never path URL. Microphone not held for network. Background
completion is bounded; otherwise preserve and foreground-resume. Cancel follows
action contract. Dedicated transcription/correction/translation/output specs apply.

Each remote stage has its own consent-gated dispatch registration and one-shot
result authority. Consumed non-empty transcription advances Pending to
postProcessing before later work. Correction is fail-open from accepted
transcript after consent withdrawal, no replacement request. Translation is
strict: ineligible untranslated intermediate is never accepted; retire authority
and durably reach awaitingRecovery before actions.

Failed local transition retains normalized result as provider-free recovery,
never rewinds/replays. After throw reload exact Pending and idempotently confirm
same phase; visible phase alone is no durability proof. Missing/mismatch blocks
without loss/replay. Emit successful-transcription usage exactly once immediately
after consent consumption; later failures do not remove/repeat it.

Historical P5H train is superseded for V1.1 but preserves precedence evidence:
when activated under its version-2 disclosure, History-on decided accepted row
before publication; History-off leaves mandatory Latest/Pending; eligible failure
may transfer audio to one failed row and retire Pending; uncertain/full/off keeps
Pending sole owner; append failure warns nonblockingly; History Retry is explicit
and cannot compete with Voice. Current V1.1 compact History/one Pending wins.
