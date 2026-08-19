# iOS V1.1 Keyboard Surface

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.keyboard-surface@1`
- Read when: governing the production command keyboard composition.
- Do not read when: only handoff transport or app navigation matters.
- Maximum size: 100 physical lines.

The selected composition is **Brand Stage**. Light/Dark geometry and hierarchy
are identical; system materials, key colors, shadows, and contrast adapt.
Reserve HoldType blue/purple for microphone and small active accents.

- Top row: Quick Insert and labeled `Auto` left, Fixes center, History plus
  `Latest` right. No duplicate brand/status; operational state is in Voice/Fixes.
- Medium central Voice indicator with bounded symmetric phase-driven waves for
  Ready, Opening, Starting, Listening, Processing, and compact failure; it
  never claims live metering. Microphone starts warm/cold handoff and becomes Finish.
- Quick Insert directly/reversibly replaces Voice with bundled local punctuation
  and emoji, no launcher/title, two emoji rows at regular height; any insertion
  closes to the exact underlying Voice state.
- Fixes directly/reversibly replaces Voice with icon/title Translate, Fix, and
  enabled custom tiles; expose no source/result and close to current Voice state.
- `Auto` independently combines Translate/Correction; microphone remains sole
  Start, incomplete Translation opens its owning input, and no Append mode exists.
- Editing row is Globe, wide Space, Delete, adaptive Return. Space short-tap
  inserts; long-press/drag moves cursor without insertion. Delete repeats with
  bounded acceleration; Return follows current input traits.
- Targets ≥44 pt; VoiceOver labels/state announcements, Dynamic Type-safe labels,
  Reduce Motion, and sufficient contrast in both appearances.
- Local Quick Insert/editing work without network/Full Access. Starting,
  Listening, and Processing keep Voice visible and disable Quick Insert/Auto.

No alphabet, number deck, `A` probe, Refresh, Shift, Caps, `123`, predictions,
or autocorrection. Arbitrary Unicode results are allowed; Globe provides normal
typing/system emoji.
