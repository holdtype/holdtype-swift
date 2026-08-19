# Shortcuts, Translation, And Fixes Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.SHORTCUTS`, `SETTINGS.TRANSLATION`, `SETTINGS.FIXES`
- Read when: shortcut editing, translation configuration, or Manage Fixes routing is in scope.
- Do not read when: only shortcut runtime activation or Fix transformation is in scope.
- Maximum size: 100 physical lines.

- Shortcut editor lists Dictation, Translation, Fixes, and Paste Last Result
  assignment, activation mode, registration state, and in-app replacement capture.
- Duplicate/unsupported candidates fail locally. Persist only after successful
  registration; failure preserves prior assignment.
- Shortcut area has no Translation toggle/language/model/prompt; it only shows assignment.
- Dedicated Translation section owns default-enabled Right Command+Option,
  source behavior, target, model, prompt, and Reset. Source defaults Same as
  Transcription; advanced source override supports common/custom. Target starts
  unconfigured; detailed semantics follow `post-transcription-actions.md`.
- Manage Fixes is a separate normal window opened from menu, never a sidebar
  section. It owns typed built-ins and custom search/add/edit/icon/enable/reorder/delete.
  Catalog edits are local and never read active text, call provider, or alter dictation.
- `text-fixes.md` has narrower precedence: there is no Restore Defaults action.
