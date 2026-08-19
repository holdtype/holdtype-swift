# Voice Emoji Catalog And Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.voice-emoji-commands@1`
- Clauses: `EMOJI.CATALOG`, `EMOJI.SETTINGS`, `EMOJI.STORAGE`
- Read when: emoji language sets, custom rows, settings placement, or storage is in scope.
- Do not read when: only matching and output order are in scope.
- Maximum size: 100 physical lines.

## Presentation and selection

- macOS keeps commands inside Dictionary and may use compact catalog tabs.
  iOS routes them under Rules → Dictation Rules, not a Settings destination,
  using native active-set selection plus searchable catalog/detail.
- Built-in sets are English, Russian, Spanish, German, French, and Portuguese;
  Japanese/Chinese wait for dedicated dictation QA.
- Selecting a built-in activates its replacement and prompt hints. Selecting
  Custom disables only built-in catalog/hints; enabled custom rows stay visible
  and active alongside any selected built-in.
- Catalogs show emoji, primary phrase, and aliases.

## Custom commands

- Users add emoji output, primary phrase, aliases, enabled state, or delete a row.
- iOS uses UUID detail editors with explicit Save and one optional alias per
  line. Draft text is memory-only; Save normalizes whitespace/duplicates.
- Output and primary phrase must normalize non-empty. A phrase/alias cannot
  belong to two custom rows. Custom/built-in overlap is allowed and custom wins.
- P3 blocks new ambiguous custom mutations but preserves readable legacy
  collisions until edited. Loading never silently removes/rewrites them.
- P3 preserves insertion order and exposes no custom reorder. Navigation state
  contains only app-owned catalog ID or row UUID, never phrase/alias/output.

## Persistence and bundled data

- macOS compatibility storage may retain enabled state, optional built-in ID,
  and custom commands in existing UserDefaults keys.
- iOS stores those values only in app-private Library v1, never UserDefaults or App Group.
- Zero built-in ID means Custom and does not disable enabled custom rows.
- Bundled catalogs are never copied into persistence.
- Every set includes ❤️ 😂 🤣 👍 😭 🙏 😘 🥰 😍 🙂 😠 ✅ ❌ 🔥 ✨ 🥹 👀 💀 🫶 🫠 💔.
