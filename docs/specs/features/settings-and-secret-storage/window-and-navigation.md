# Settings Window And Navigation

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clause: `SETTINGS.WINDOW`
- Read when: Settings window structure, section routing, or shared field presentation is in scope.
- Do not read when: only one feature's persisted value is in scope.
- Maximum size: 100 physical lines.

- Before real fields exist, a native HoldType Settings placeholder may appear
  but never fake controls.
- Multi-group Settings uses a sidebar with stable Permissions, API key, Billing,
  Transcription, Text Correction, Translation, Dictionary, Shortcut, Behavior,
  Recording Cache, Updates, and Diagnostics entries. Permissions is default;
  there is no duplicative General section.
- Window title is `HoldType: <section title>` and updates in place when selection changes.
- Permissions owns only genuine microphone/AX/Input Monitoring status/actions,
  never API-key state. While visible it lightly polls and refreshes on app/key
  focus; setup-affecting changes refresh immediately. Keychain is excluded.
- Technical inputs (keys, model/language codes, dictionary/replacements, prompts)
  are leading and LTR regardless of locale/content. Prompt text areas fill
  width; header Reset does not consume their width and a visible gap separates them.
- Dev Vlogs is a separate normal window/domain store, not a sidebar section or
  large Settings owner. It may read shared mic status but owns no permission request.
  Small preferences are local feature data; destination bookmarks/archive
  metadata remain dedicated and never become Keychain/History/cache/usage data.
