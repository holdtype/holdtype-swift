# Voice Emoji Commands

- Node type: hybrid
- Contract ID: `holdtype.shared.voice-emoji-commands`
- Domain ID: `holdtype.shared.voice-emoji-commands`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; iOS scope governed by current iOS contracts
- Contract revision: `holdtype.shared.voice-emoji-commands@1`
- Read when: spoken emoji catalogs, prompt hints, matching, or output handoff is in scope.
- Do not read when: only ordinary dictionary replacement rules are in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Replace short, explicit spoken commands with common emoji without becoming an
emoji picker, generic text expander, cloud-synced catalog, or second OpenAI request.

## Children

- [Catalog and settings](voice-emoji-commands/catalog-and-settings.md) — built-in languages, custom rows, placement, persistence, and prompt hints.
- [Matching and output](voice-emoji-commands/matching-and-output.md) — local replacement, precedence, pipeline order, privacy, and verification.

## Shared invariants

- One top-level toggle controls emoji commands; English is the default built-in set.
- Explicit language prefixes are required; ordinary unprefixed words remain text.
- Replacement is local, makes no extra provider request, and runs after accepted
  transcription but before user replacement rules.
- Custom commands win phrase collisions with built-ins. Longest word-bounded,
  case-insensitive match wins among overlaps.
- Last Transcript, History, Last Result, and automatic insertion receive final
  emoji-expanded text.

## Dependencies and unknown

- `text-correction.md` owns the local post-processing order; this consumer
  reference is non-recursive because Text Correction depends on this contract.
- Current iOS settings/storage contracts govern app-private persistence and
  more-specific route presentation.

Whether the selected built-in set should follow transcription language remains
open pending dedicated dictation QA; English remains the default meanwhile.
