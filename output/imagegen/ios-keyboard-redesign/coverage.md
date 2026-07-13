# iOS keyboard redesign coverage

The approved Option 2 composition remains the visual source for the Brand
Stage keyboard. The production implementation adapts it to native iOS touch
targets and system Light/Dark appearance without adding a QWERTY layout or
rendering transcript data inside the extension.

| Component | Approved reference | Implementation | Runtime evidence |
| --- | --- | --- | --- |
| Rounded keyboard shell | `approved-option-2-reference.png` | Distinct cool-light/deep-navy surfaces with rounded top corners | [iPhone Light](../../../docs/qa/runs/assets/ios-brand-stage-keyboard-2026-07-13/iphone-light.png), [iPhone Dark](../../../docs/qa/runs/assets/ios-brand-stage-keyboard-2026-07-13/iphone-dark.png) |
| Top rail | History left, transparent HoldType mark and terse status centered, Latest right | Equal 88 x 44 point actions; `Ready` or one short problem label only | Both runtime captures |
| Voice stage | Centered microphone and symmetric waveform | 80-point non-interactive microphone stage with bounded 21-bar waveform on each side | Both runtime captures |
| Punctuation row | Four equal actions | `.`, `,`, `?`, and `!` with equal geometry | Both runtime captures |
| Editing row | Narrow Globe, dominant Space, medium Delete and Return | Reference-derived ratios, cursor drag on Space, bounded Delete repeat, adaptive Return | Both runtime captures |
| Themes | Dark approved source | Geometry is unchanged between Light and Dark; only native materials, contrast, and accent colors adapt | [iPad Light](../../../docs/qa/runs/assets/ios-brand-stage-keyboard-2026-07-13/ipad-light.png), [iPad Dark](../../../docs/qa/runs/assets/ios-brand-stage-keyboard-2026-07-13/ipad-dark.png) |

History opens no inline content and Latest never previews text. History rows,
transcript cards, QWERTY rows, menus, settings, the old `A` probe, and long
status copy are excluded from the keyboard surface.
