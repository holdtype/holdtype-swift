# Translation Settings and Preflight

- Node type: leaf
- Contract ID: `holdtype.macos.post-transcription-actions.settings`
- Domain ID: `holdtype.macos.post-transcription-actions`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.post-transcription-actions.settings@1`
- Read when: translation shortcut, source/target route, prompt, or readiness is in scope.
- Do not read when: only provider cancellation or accepted output is in scope.
- Maximum size: 100 physical lines.

## Intent and defaults

- Normal Right Command remains ordinary dictation.
- Translation defaults enabled with editable hold-to-record assignment
  `Right Command+Option`; assignment lives in Shortcut Settings, enablement in Translation.
- Target language starts unconfigured on new installs and is required.
- Settings shows source behavior, target, model, editable prompt, and Reset;
  prompt remains editable while disabled and blank/whitespace uses default.

## Language routing

- Source defaults Same as Transcription and never overrides transcription language.
- Same+Auto sends no source code; fixed/custom uses effective transcription code.
- Optional Override and target offer common presets plus Custom.
- Missing/invalid target or invalid override fails immediately, makes no known-
  invalid transcription/translation request, and opens Settings focused on
  Translation without focusing model/prompt fields.
- Promoting active normal recording to translation before stop applies the same
  preflight and stops/fails before requests when invalid.
- Disabled translation assignment creates no translation request and leaves Dictation independent.

## Provider output contract

- Response is only translated text—no notes, Markdown, alternatives,
  diagnostics, explanation, or source text.
- Immediate Translate Fix may reuse saved route/provider but changes only its
  captured target and never Last Transcript, Last Result, History, or insertion.

## Dependencies

- [Post-transcription actions](../post-transcription-actions.md) — shared strict intent.
