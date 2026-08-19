# iOS Replacement Library

- Node type: leaf
- Contract ID: `holdtype.shared.text-correction.ios-library`
- Domain ID: `holdtype.shared.text-correction`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.text-correction.ios-library@1`
- Read when: iOS Replacement Rules list, detail, search, status, reorder, enablement, or deletion is in scope.
- Do not read when: only local replacement execution or OpenAI correction is in scope.
- Maximum size: 100 physical lines.

## List and summary

- Searchable Library list uses UUID detail editors with explicit Save. Add,
  enablement, confirmed delete, and reorder are separate atomic actions.
- New rule requires non-whitespace Search for first Save, becomes enabled, and
  appends after last. Identical Search is valid; duplicates remain separate.
- Existing empty Search stays visible/editable/preservable as inactive.
- Summary is `0 custom rules` or `N custom rules · M active`; active means
  enabled plus non-whitespace Search.
- Rows preserve durable order and show raw Search, Replacement, and exact status:
  empty Search → `Inactive — empty search` regardless of enabled; otherwise
  disabled → `Off`; enabled → `Active`.
- Empty Replacement visibly means remove matches; whitespace-only is labelled accordingly.

## Search and reorder

- Non-whitespace ephemeral query case-insensitively filters raw Search and
  Replacement without mutation, reordering, or merging duplicates.
- Active search exits edit mode, hides reorder, and cannot reorder subset;
  clearing restores durable order.
- Native list editing and VoiceOver moves submit expected complete UUID sequence
  and requested sequence containing the same IDs.
- Optimistic order contains IDs only, reads latest durable fields, and rolls
  back after failure/conflict.

## Detail and deletion

- Draft owns only raw Search/Replacement; enabled is separate list action.
- Editing never trims, folds, deduplicates, autocorrects, capitalizes, or rewrites.
  Both fields are multiline and preserve outer whitespace/newlines.
- Disable per-field smart quotes/dashes, inline completion, and Writing Tools;
  system-only shortcuts remain system-owned and their result is stored unchanged.
- Existing blank Search and empty Replacement may save; new empty Replacement may save.
- Confirmed Delete exists from list/existing detail; deleting dirty draft confirms discard.

## Cleanup setting

iOS Replacements shows the same durable local-cleanup preference before rules,
states default/local behavior and all transformation groups. It is not a second
setting or synthetic rule collection.

## Dependencies

- [Text correction](../text-correction.md) — shared replacement semantics.
