# Voice Draft Design QA

Source visual truth:
`/Users/eugenepotapenko/.codex/generated_images/019f60b9-4dc4-7371-842d-88ebf0ed1b37/exec-487ff58c-ef0c-49c4-83b4-6cab84b4e6d0.png`

Implementation screenshot:
`docs/qa/runs/assets/ios-voice-actions-2026-07-14/iphone-16-light.png`

Viewport: iPhone 16, iOS 18.6 Simulator, 393 × 852 points at 3×.

State: populated read-only Draft, Voice ready, standard Dynamic Type, Light.

Baseline composition comparison from the initial Voice Draft pass:
`docs/qa/runs/assets/ios-voice-draft-2026-07-14/reference-vs-implementation.png`

Focused evidence: the fresh full-view screenshot keeps the generated bubble,
native microphone, title, Draft typography, one-shot action row, and tab labels
large enough to inspect. The paired setup-blocked screenshot at
`docs/qa/runs/assets/ios-voice-actions-2026-07-14/iphone-16-setup-blocked.png`
proves the same layout with disabled processing and recording actions.

## Findings

No actionable P0, P1, or P2 differences remain.

- Typography uses the native iOS type scale and weights. The reference's
  editable UI labels were intentionally rebuilt as native text instead of
  raster content; standard and accessibility sizes remain readable.
- Spacing preserves the reference's quiet vertical hierarchy while adding the
  approved Draft surface, two compact one-shot actions, and bottom tab bar. The
  large primary control remains in the lower thumb region without clipping.
- Colors use semantic system backgrounds plus the reference cyan-blue-violet
  accent. The disabled control becomes visibly grey and Dark appearance keeps
  sufficient separation.
- The button background is a dedicated generated raster asset at 208, 416,
  and 624 pixels with alpha. The microphone and label remain native so they
  are sharp, localizable, and state-aware.
- Copy is coherent with the standalone app flow. History is intentionally the
  separate first-level tab approved after the source mockup, not the mockup's
  duplicate top action.
- SF Symbols provide consistent native toolbar, Draft, status, and tab icons.
- Ready and setup-blocked one-shot-action states have fresh rendered evidence;
  the prior Voice Draft pass retains Dark and accessibility-size coverage. The
  Draft is static text in a scroll surface rather than a focusable input.

## Patches Made During QA

- Added compact, equally weighted Translate and Correction buttons above the
  Draft after the product contract changed from menu-only Translation.
- Reused the keyboard's established book and wand symbol language without
  sharing the keyboard UI component or introducing toggle state.
- Bounded the Draft surface and added an adaptive outer scroll container.
- Increased the primary bubble from 164 to 208 points and regenerated all
  Retina scales from the 1024-pixel ImageGen master.
- Rebalanced the native microphone and two-line label inside the bubble.
- Added bottom tabs to the deterministic qualification host and verified the
  exact disabled recovery state.

## Follow-up Polish

- [P3] A future motion pass may add a restrained listening pulse after the
  recording animation language is defined for the whole app.

## Implementation Checklist

- [x] Approved static Draft and action hierarchy.
- [x] Large generated button asset with native state overlays.
- [x] Visible one-shot Translate and Correction actions with disabled states.
- [x] Light, Dark, blocked, and accessibility-size rendered checks.
- [x] No unresolved P0/P1/P2 visual findings.

final result: passed
