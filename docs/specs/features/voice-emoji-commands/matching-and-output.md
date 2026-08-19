# Voice Emoji Matching And Output

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.voice-emoji-commands@1`
- Clauses: `EMOJI.MATCH`, `EMOJI.PIPELINE`, `EMOJI.VERIFY`
- Read when: spoken-command matching, replacement order, privacy, or verification is in scope.
- Do not read when: only catalog editing or persistence is in scope.
- Maximum size: 100 physical lines.

## Matching

- English requires `emoji` (for example `emoji smile`); Russian requires
  `эмодзи` (for example `эмодзи улыбка`). Each built-in set uses its canonical
  emoji term; translations such as `эмоции` never trigger replacement.
- Matching is case-insensitive where supported, word-token bounded, and
  longest-phrase-first. It is never broad substring replacement.
- Known commands work repeatedly and inline. Adjacent punctuation is preserved;
  punctuation/whitespace between command words may still match (`эмодзи, смайл`).
- Unknown commands and unprefixed ordinary words remain dictated text.
- Enabled custom commands are active only under the top-level toggle; custom
  wins an identical built-in phrase.

## Pipeline and privacy

- Active built-in/custom phrases may be included as app-owned OpenAI
  transcription prompt hints, but replacement itself is local and makes no
  additional provider request.
- Built-in hints never appear as user-authored dictionary rows.
- User replacement rules run after emoji replacement and may customize final output.
- Default logs omit raw transcript, command input, hints, and output.
- Final emoji-expanded text reaches Last Transcript, History, Last Result, and insertion.

## Verification

Settings tests cover defaults, persistence, and prompt hints for enabled
built-in/custom sets. Processing tests cover English/Russian, custom/disabled/
unknown commands, repeats, punctuation-tolerant inline matches, collisions, and
user replacements after emoji. Presentation tests cover platform placement
when a stable UI-test surface exists.
