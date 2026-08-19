# Historical Consent Record And Presentation

- Node type: leaf
- Status: Historical
- Read when: reviewing legacy strict wire format or observation states.
- Do not read when: authorizing current provider work by this node alone.
- Maximum size: 100 physical lines.

Canonical path was `HoldType/ios-openai-provider-consent.json`. Strict ≤4096-byte
UTF-8 v1 object exactly schemaVersion 1, lowercase UUID epochID, revision 1…Int64,
positive disclosureVersion, accepted/withdrawn, canonical millisecond UTC date
(`yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`, Gregorian/no leap second). No BOM/duplicates/
unknown/missing/null/nesting/arrays/aliases/noncanonical values. Bad/future bytes
preserved. Missing meant stable absent/no write; only exact current accepted authorized.

Historical disclosure v1 was foreground/no History/cache; frozen v2 described
20 accepted/five failed rows, retry audio, independent lifetimes and local controls,
without activating policy/rows/provider. That version is superseded.

One process coordinator/root served scenes/stages. Passive content-free states:
not reviewed, review required, current accepted, withdrawn, data unavailable,
optionally decision date—no path/bytes/IDs/errors. Observation did no external work.
All values/errors/authorization redacted.
