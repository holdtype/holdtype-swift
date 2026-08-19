# iOS Library Record V1

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.library-record@1`
- Read when: encoding/decoding Dictionary, Emoji Commands, or Replacements.
- Do not read when: editing Fixes or general settings only.
- Maximum size: 100 physical lines.

Path `HoldType/ios-library.json`, app-private Application Support, no defaults/
cloud/bridge. Runtime non-Codable Equatable/Sendable contains dictionary, emoji
configuration, ordered replacements. Defaults: empty dictionary; emoji on,
English only, no custom; no replacements.

V1 root only schema/dictionary/emojiCommands/replacementRules. Canonical save
writes all sorted keys, preserves replacement order/UUID/raw fields, custom order/
UUID, surviving dictionary order. Normalize dictionary and each custom row
independently; retain UUID-distinct semantic equivalents. Repeated replacement
search is valid. Canonicalize UUID spelling without identity change.

Missing known groups/fields may default, but every row field required. Null/type/
non-object/bad ID/unexpected field fails. Custom row requires non-empty normalized
emoji/phrases; never merge equivalents. Schema exactly 1; no inferred migration.
Built-ins exactly `en ru es de fr pt`; validate before zero/one cardinality.
Custom UUID unique within custom; replacement UUID within replacement; cross-
collection reuse allowed. Duplicate check precedes usability.

Errors expose known path/class only, never content/unknowns/path/system numbers.
Missing returns defaults without write; bad bytes preserved. One process actor,
1 MiB protected atomic backup-eligible boundary. Encoder structurally validates
canonical bytes before replace, not byte-size alone.

Exactly one composition Settings owner and Library owner; failed-Retry consumes
them. No scene repository/read-then-full-save. Simulator proves requested
protection; signed device proves effective.
