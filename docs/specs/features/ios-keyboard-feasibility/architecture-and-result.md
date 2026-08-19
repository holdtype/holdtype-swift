# Historical Keyboard Architecture And K1 Result

- Node type: leaf
- Status: Historical
- Read when: interpreting the original K1 decision.
- Do not read when: implementing current keyboard behavior.
- Maximum size: 100 physical lines.

The app owned onboarding/mic/OpenAI/recovery/settings/secrets/Library/Latest/
History; extension owned local editing and explicit insertion. App alone wrote
one accepted-History-latest snapshot; extension never recorded/read Keychain/
called OpenAI/rendered or mutated History.

K1 found custom keyboards could not reuse Apple's keyboard, documented opening
did not cover keyboard extensions, Review 4.4.1 restricted app launch, and no
public host identity/automatic-return contract existed. No private workaround.
Historical Brand Stage used local editing/Latest/History navigation and no
typing engine. App Group was atomic app-write/read-only, one safe item, no
content/secrets/audio/settings; bad state disabled insertion. The old probe set
`RequestsOpenAccess=false`/`hasDictationKey=false`; metadata was not product language.

K1 therefore did not qualify keyboard-started voice and rejected custom URL,
hidden lookup, responder launch, and instruction-only microphone. Fallback was
app Voice+Copy+system keyboard. This conclusion was later superseded only by
the current explicit handoff contract and its signed-device gate.
