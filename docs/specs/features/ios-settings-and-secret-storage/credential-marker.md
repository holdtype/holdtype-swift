# iOS Credential-Presence Marker V1

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.credential-marker@1`
- Read when: encoding/decoding the non-secret Keychain-presence marker.
- Do not read when: resolving actual credential content.
- Maximum size: 100 physical lines.

Runtime has update date and exactly one state: present, absent, unknown, or
mutationInProgress. Only mutationInProgress has kind saveOrReplace/remove.

Private v1 contains only schemaVersion/state/updatedAt/conditional mutationKind;
no key/mask/Keychain identity/provider/App Group/keyboard. Missing means no marker,
not absent. Atomic Complete-protected replacements exclude backup; failure
preserves bytes. Corrupt/unsupported/unexpected/invalid combination is typed,
content-free and byte-preserved. Dispatch begins v1; no inferred legacy migration.
