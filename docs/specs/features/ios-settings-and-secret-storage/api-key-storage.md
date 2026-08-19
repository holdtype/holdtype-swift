# iOS API-Key Storage

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.api-key@1`
- Read when: saving, resolving, removing, or using the OpenAI credential.
- Do not read when: only non-secret settings or UI layout matters.
- Maximum size: 100 physical lines.

Use one generic-password item: service `app.holdtype.HoldType.ios`, account
`openai-api-key`, non-sync, `WhenUnlockedThisDeviceOnly`, exact built-in signed
application-identifier access group expanded at build. Never wildcard/shared/
dynamic bundle identity. Missing/unsigned/unresolved/wrong fails before Security;
unauthorized well-shaped group fails redacted. Extension gets no key/metadata.

Replace updates, then add, then update on race—never delete first. Locked and
invalid are distinct typed/redacted; remove missing succeeds. No launch/passive/
permission/keyboard/diagnostics read. Automation/XCTest chooses process-local
disabled mode before coordinator; every operation fails before Security and
does not imply absence. No macOS debug-file exception.

Manual secure scene-local draft commits on Done/Return or leaving non-empty
valid candidate; typing never operates. Adjacent icon Paste reads only on tap
and commits; no Save button/passive clipboard. Draft may survive dismissal for
retry but enters no owner/scene storage/settings/log/bridge. Success clears;
failure keeps masked draft, old item/status. Reject blank, no `sk-` inference.
Remove is confirmed; failure keeps status/draft. One in-progress action disables
refresh/save/paste/remove.

One process coordinator serializes whole save/remove/refresh/preflight operations
and marker/Keychain/cache steps FIFO across scenes; cancellation before lease is
no-op, after durable marker continues reconciliation. Production never constructs
scene coordinator or calls adapters. Stable marker path is
`HoldType/ios-openai-credential-presence.json`; no alternate caller path.

Replacement failure preserves old item/cache. Provider rejection never mutates
key; it is process-only for exact generation, stale rejection ignored, rejected
generation not reused. Provider services receive resolved credential, never read
Keychain. Transient non-Codable value trims outer whitespace/rejects empty and
redacts String/debug/reflection; never persists/logs/bridges.

Voice resolves in foreground before capture; locked/unavailable blocks or waits
completed Pending. Public purposes: explicit Settings refresh (always Keychain)
and requested voice preflight (current cache/known absence). Failed-History Retry
uses exact process owners/coordinator/settings/Library/consent, then one transient
adapter before durable reservation; no caller eligibility flag/snapshot. Passive
launch/cleanup/reads/process-loss recovery do no Keychain/provider construction.
