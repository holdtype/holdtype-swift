# Text Fixes Catalog And Profiles

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.text-fixes@3`
- Clauses: `TF.CATALOG`, `TF.PROFILE`, `TF.MIGRATION`
- Read when: Fix catalog records, profiles, ordering, or migration is in scope.
- Do not read when: only target replacement or platform presentation is in scope.
- Maximum size: 100 physical lines.

## Catalog

- **Fixes** names the feature/catalog; one item is a **Fix**.
- Pinned typed actions are `Translate`, using saved Translation settings, and
  `Correct Text`, forcing the saved Writing & Correction model/prompt without
  changing the automatic-correction preference. They cannot be deleted or
  converted to prompts.
- New catalogs add editable Improve Writing, Make Shorter, Summarize, Bullet
  Points, Change to Casual, and Markdown prompts.
- A custom Fix has a stable ID, required title (at most 80 user-perceived
  characters), supported SF Symbol, required prompt (at most 8 KiB UTF-8),
  processing profile, enabled state, and position after the built-ins.

## Processing profiles

- `Use Writing & Correction Settings` is the default and uses that saved model
  route with low reasoning.
- `GPT-5.6 Terra` uses `gpt-5.6-terra` with medium reasoning.
- `GPT-5.6 Sol — Best Quality` uses `gpt-5.6-sol` with maximum reasoning.
- `Custom` requires a non-empty model identifier of at most 128 UTF-8 bytes
  and an explicit supported reasoning effort.

## Editing and persistence

- Users may add, edit, reorder, enable, disable, and delete custom Fixes.
  macOS drag-reorders unfiltered custom rows; built-ins remain pinned.
- There is no Restore Defaults. Catalogs are local and separate on macOS/iOS.
- Corrupt/unsupported data is preserved and reported, not overwritten by defaults.
- Only the exact former `builtin.fix` payload migrates its label to `Correct
  Text`; custom titles/prompts remain unchanged and other invalid built-ins remain corrupt.
- macOS recent use stores only action ID and last successful immediate-use time.
- `Voice Prompt…` is a transient macOS palette command, never a persisted,
  synced, reordered, edited, or iOS-projected catalog action.

Catalog schema v2 stores processing profiles. A valid v1 catalog loads custom
Fixes with the default profile and is not rewritten until the next valid save.
The writing-skill addendum advances the shared schema to v3 without weakening
these migrations.
