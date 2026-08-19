# iOS Library And Fixes Editors

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.library-editors@1`
- Read when: editing Dictionary, Emoji, Replacements, or Fixes.
- Do not read when: only general autosave or Keychain matters.
- Maximum size: 100 physical lines.

Library routes: Dictionary, Voice Emoji, Replacements, Fixes via lists/details;
no import/export/cloud/dictionary reorder/custom-command reorder. Fixes has own
owner/record; Translate/Fix first, customs Add/explicit Save/icon/enable/reorder/
confirmed Delete/Restore. Fix draft title/prompt/icon does no external work and
never leaks. Keyboard receives enabled ID/kind/title/icon/order only.

Replacements begins Automatic Cleanup using general Boolean with full categories,
then Custom list; same preference as Writing toggle, no built-in rows/move to
Library. General and Library states/failures stay isolated; Boolean update cannot
overwrite correction fields.

All Library mutations are typed against latest durable owner and return canonical
state plus committed/unchanged/duplicate/missing/conflict/invalid; noncommits do
no write. Dictionary batch parses comma/newline, trims/dedupes latest, atomically
adds unique and reports counts; empty invalid. Removal uses semantic trim+lower
plus exact displayed expected, never index.

Emoji/replacement UUID created once and CAS full expected row; toggle CAS prior
Boolean. Missing never resurrects. Emoji needs normalized output/primary phrase;
any phrase belongs to at most one custom row, while built-in overlap allowed.
Readable legacy collisions remain, never silently changed. Global/built-in
selection changes only own fields.

Replacement raw order/UUID/duplicates preserved. Existing whitespace search is
stored but inactive; new requires nonblank; append enabled; empty replacement
allowed. Full-row conflict supports separately confirmed Replace Latest; toggle
preserves concurrent fields. Reorder CAS complete same-ID sequence; concurrent
insert/delete/reorder conflicts, field changes retained; unavailable under filter.
Failure restores durable order.

Dirty detail adopts durable when clean; otherwise Changed Elsewhere with Reload
or confirmed Replace Latest. Deletion disables Save. Explicit operations atomic.
Dirty drafts use discard guard; failed keeps Not Saved. In-flight Save/Delete
keeps destination and blocks tab/sidebar with wait alert until terminal.
Queries/drafts/content/keys never enter navigation IDs/SceneStorage/accessibility
IDs/notices/reflection/logs. Content remains VoiceOver-visible, app-private,
backup-eligible; CRUD does no external action.

Fixes v1 path `HoldType/ios-text-fixes.json`: schema plus ordered custom rows;
typed Translate/Fix defaults. Unique UUID/title/prompt/supported icon/enabled/
order, limits/defaults per Fixes contract. Missing defaults without write; bad
bytes preserved. Protected atomic owner; keyboard metadata is replaceable cache
whose failure never mutates catalog.
