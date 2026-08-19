# iOS Voice Durable State

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-state.durable@1`
- Read when: decoding or mutating canonical Pending/Latest state.
- Do not read when: only UI recovery presentation matters.
- Maximum size: 100 physical lines.

The app owns at most one Pending (`attemptID`, protected audio) and one Latest
(`resultID`, source attempt, accepted text, date), plus separate compact History.

Pending meanings: `ready` (explicit flow may send), `processing` (this process
started provider), `failed` (audio retained; Retry only with proven safe stage),
and `acceptedCleanup` (Latest committed; only local History/cleanup remains).

After transcription, durably store normalized transcript, operation ID, current
downstream text, and exactly one boundary:

- `transcriptionAccepted`: correction/local processing may start without retranscription;
- `correctionInFlight`: unknown result; Retry fails open from pre-correction text;
- `translationReady`: explicit Retry may attempt translation;
- `translationInFlight`: outcome unknown; Play/Discard only, never replay;
- `outputReady`: resume local acceptance without provider setup/consent/key.

Commit transcription checkpoint before correction, translation, or delivery.
If unconfirmed, fail locally and never auto-repeat transcription.

Store the 1–15 minute limit frozen at Start; old schemas become five minutes.
Recovery/duration/limit retention use stored, never current, Settings. Record
ordinary cache-policy retention versus protected limit-ended retention for
automatic Finish or canonical media within 500 ms of frozen boundary when Done
wins. Retention does not change provider eligibility or add provider state.

Persist no credential, prompt, provider body/response, or History transaction
capability—only bounded normalized text/stage evidence. Raw audio remains its
separate protected file.
