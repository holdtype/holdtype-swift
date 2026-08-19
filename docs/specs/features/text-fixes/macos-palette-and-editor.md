# macOS Fixes Palette And Editor

- Node type: leaf
- Status: Active
- Stability: legacy-released
- Parent contract: `holdtype.shared.text-fixes@3`
- Clauses: `TF.MACOS.PALETTE`, `TF.MACOS.EDITOR`
- Read when: macOS Fixes shortcut, palette, unavailable dialog, or editor is in scope.
- Do not read when: only shared processing or iOS presentation is in scope.
- Maximum size: 100 physical lines.

## Palette and unavailable feedback

- Default global shortcut is `Option+J` (`⌥J`) and reacts only to its full
  confirmed press/release. It captures the external target before UI.
- No compatible external text target means no UI. A found but unusable control
  shows a centered compact SwiftUI-content dialog with title, readable reason,
  OK, Escape/outside/4-second dismissal, and no sound or palette controls.
- The non-activating palette is centered on the target display, preserves
  external focus, and supports click-outside dismissal. It shows at most five
  enabled rows: recent successes first, then catalog order; first row is selected.
- Filtering ranks exact/prefix then other title matches, with recency ties.
  Arrows select, Return runs, Escape/outside dismiss. `Voice Prompt…` remains
  independently available and shows Listening/Transcribing/Applying states.
- A translated language code renders `Translate to <normalized two-letter code>`.
  Success updates recency and dismisses; retry requires a still-valid snapshot.
- Shortcut registration failure reports unavailable without a menu palette fallback.
  Fixes needs API key and AX trust, no separate consent; Input Monitoring only
  when the chosen shortcut path requires it. Menu exposes only `Manage Fixes…`.

## Manage Fixes

- Reopening closes an existing editor, preserves autosave-before-close, waits
  for closure, then fronts a fresh native `Manage Fixes` window.
- Sidebar has Search and equal compact `+`/`−` footer controls. Plus stays
  visible while filtered; minus removes only a selected custom Fix. Custom
  context-menu deletion is allowed and irreversible deletion confirms.
- Creation clears search, appends/selects `Untitled Fix`, opens detail, and
  focuses/selects the title. Custom rows drag-reorder only when unfiltered.
- Detail edits title, prompt, icon, profile, and enabled state. Sol Best Quality
  prominently warns it is slower, uses the user's OpenAI account, and typically
  costs `$0.08–$0.14` per medium social post at 2026-08-12 pricing; charges vary.
  Custom profile reveals model/reasoning. Autosave is 500 ms and flushes before
  selection/close; there are no detail Save/Delete or Order controls.
- Content begins with two-line help for field/selection behavior and ⌥J keys.
  No selection has a concise empty state. Built-ins show locked information and
  only a navigation button to Translation or Text Correction Settings.

The panel shell may use only the repository's narrow approved AppKit exception;
all visible palette/dialog/editor content remains SwiftUI.
