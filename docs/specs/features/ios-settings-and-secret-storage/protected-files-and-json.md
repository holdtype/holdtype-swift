# iOS Protected Files And JSON

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.files@1`
- Read when: reading/writing settings metadata or validating persisted JSON.
- Do not read when: only editor behavior matters.
- Maximum size: 100 physical lines.

Settings, Library, Fixes, marker, consent share app-private regular-file boundary;
reject symlink/directory/special without following. Limits: marker 16 KiB,
consent 4 KiB, others 1 MiB; exact accepted, +1 rejected unchanged. Pin identity;
size and modification/change timestamps stable through read. Save aborts if
destination changed, even same inode/size.

Oversized save fails before temp. Valid save creates exclusive owner-only regular
temp beside destination, applies Complete protection before first write plus
backup policy, writes/syncs, validates identity/size, atomically publishes.
Failure preserves destination and removes only owned temp; raced replacement is
never written/deleted. Sandbox/serialized ownership is assumed; no hostile same-
UID kernel conditional-unlink claim. General/Library/marker report success after
rename/remove despite best-effort dir-sync; consent requires dir sync and uses
its fail-closed reconciliation.

Before Foundation dictionary decode, shared full-source structural pass accepts
strict UTF-8 JSON/whitespace; rejects BOM, invalid/truncated/multiple values.
Duplicate names use decoded Swift String equality including escapes/canonical
Unicode, but not case/compatibility folding, at every nesting level.

Limits: 64 nesting, 1,024 members/object, 262,144 members total, 65,536 items/
array, 524,288 values, 4,096 decoded UTF-8 bytes/name, 256-byte number. Byte
limit wins first; structural failure maps corrupt, precedes schema/field checks.
Every failure preserves exact source with no rewrite/removal/default/compaction.
Scope is app-private persistence, not App Group/macOS stores.
