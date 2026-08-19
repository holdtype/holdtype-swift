# iOS General Settings Record V1

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.record@1`
- Read when: encoding/decoding the app-private general settings record.
- Do not read when: Library, credential, consent, History, or bridge data matters.
- Maximum size: 100 physical lines.

Path `HoldType/ios-app-settings.json` under app Application Support; never
UserDefaults/App Group/cloud. V1 only transcription, correction, cleanup,
translation, Keep Latest, cues/tail. Exclude key/marker, Library, History, usage,
diagnostics, recovery/audio/retention, auto insertion, typing, Nearby Text,
macOS, consent, Full Access.

Runtime is Equatable/Sendable, non-Codable; private DTO. Required integer
`schemaVersion=1`; canonical save writes every v1 field/group including defaults.
Load may default missing known group/field. Malformed/non-object/missing or bad
schema/null/wrong known value/unexpected field/unknown enum are distinct typed,
content-free known-path errors. v0/future unsupported; no inferred migration.

Missing returns full defaults without write. Corrupt/unsupported bytes are
preserved. One process repository serializes load/save; same-dir atomic replace,
Complete protection, backup eligible; failure preserves durable. Simulator proves
request only; signed device proves effective protection.
