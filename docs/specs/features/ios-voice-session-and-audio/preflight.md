# iOS Foreground Voice Preflight

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.preflight@1`
- Read when: admitting a new foreground attempt.
- Do not read when: capture is already retained.
- Maximum size: 100 physical lines.

One process Voice owner serves all scenes. Explicit inactive Start only; durable
preflight separately proves Pending ownership. In order:

1. acquire process Start; reject competing work without disturbance;
2. require foreground-active scene; initiator owns consent/permission UI;
3. reconcile canonical storage; any valid/unreadable/corrupt/future/uncertain
   Pending blocks second capture and shows exact recovery;
4. freeze durable Settings+Library and validate Standard/Translate intent;
5. require/obtain current durable provider consent;
6. resolve one credential generation; missing/locked/rejected routes OpenAI;
7. read mic permission and request only undetermined;
8. stop History playback/deactivate it, configure/activate recording, finish
   enabled start cue, retain utterance.

Failure/cancel short-circuits later steps: storage/config precedes consent/key;
consent precedes key/mic; denial precedes audio/file. Consent acceptance is same
flow; decline/dismiss returns inactive. No connectivity probe/provider pre-capture.
