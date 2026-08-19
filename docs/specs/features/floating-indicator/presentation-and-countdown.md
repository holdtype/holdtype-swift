# Floating Indicator Presentation and Countdown

- Node type: leaf
- Contract ID: `holdtype.macos.floating-indicator.presentation`
- Domain ID: `holdtype.macos.floating-indicator`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.floating-indicator.presentation@1`
- Read when: indicator visuals, countdown, appearance, or placement is in scope.
- Do not read when: only visibility ownership or failure ordering is in scope.
- Maximum size: 100 physical lines.

## Recording and transcription visuals

- `showFloatingIndicator` enables the indicator by default.
- Enabled recording shows a compact cyan mark with subtle pulse animation.
- Transcribing may remain visible as a compact purple waiting visual whose
  motion is distinct from recording.
- The indicator uses one shared visual treatment across light and dark system
  appearance; dark mode does not select a separate night icon set.
- No text or full transcript is shown by default.

## Final 15 seconds

- Remaining whole seconds appear in a centered, high-contrast circular badge
  without transcript content.
- The badge uses white monospaced digits on a fixed dark background and updates
  once per second without number-transition animation.
- From 15 through 11 seconds the normal cyan orbit is unchanged.
- From 10 through 1 seconds the orbit is yellow while the badge retains the
  same dark-and-white treatment.

## Placement

- Default placement is near the bottom-right of the active display, within its
  visible screen area.
- Placement may adjust to remain onscreen and avoid system UI.
- If the active display changes, the indicator may stay on the session's
  starting display or move to the current display if it stays visible and
  non-disruptive.

## Dependencies

- [Floating indicator](../floating-indicator.md) — shared non-interference rules.
- [Microphone input](../microphone-text-input.md) — maximum-duration timing.
