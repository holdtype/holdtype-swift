# Transcription And Dictionary Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.TRANSCRIPTION`, `SETTINGS.DICTIONARY`, `SETTINGS.CORRECTION`
- Read when: model/language/prompt, Nearby Text, dictionary, emoji, or correction settings is in scope.
- Do not read when: only credential or output behavior is in scope.
- Maximum size: 100 physical lines.

- Transcription exposes OpenAI file model, Auto/common/custom language, and
  optional guidance prompt—no local downloads, providers, self-hosting, or account modes.
- Empty Custom language falls back to Auto; non-empty must be a 2/3-letter code.
  Empty model uses configured default or setup-needed state.
- Nearby Text is off by default. When enabled it may read a bounded AX excerpt
  for this request; unavailable/untrusted AX simply omits it and continues.
- Dictionary provides single-line add/remove. Enter trims/adds, clears, and
  preserves focus. Ignore empty and case-insensitive duplicates while preserving
  the first spelling.
- Emoji commands are a compact Dictionary feature, not their own section, and
  follow `voice-emoji-commands.md`.
- Text Correction has its own section. Remote correction defaults off; local
  typography may default on. Detailed behavior follows `text-correction.md`.
