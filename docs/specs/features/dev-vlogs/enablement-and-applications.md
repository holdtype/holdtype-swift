# Dev Vlogs Enablement And Applications

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-ENABLE-1..7`, `DV-APP-1..7`
- Read when: setup, readiness, Camera permission, app scope, or trigger identity is in scope.
- Do not read when: only media finalization or Build is in scope.
- Maximum size: 100 physical lines.

- New/existing installs default Off. Enablement is explicit in Dev Vlogs,
  never Permissions, and starts no capture. Ready requires camera, destination,
  and app scope. Disable affects future/active vlog branch safely, not dictation
  or existing clips.
- Camera permission is optional to HoldType and requested only by explicit
  camera action after enable/test intent. Missing/denied never blocks launch,
  dictation, or appears as microphone failure.
- Default/recommended scope is Only selected apps with an initially empty list.
  All apps except exclusions is secondary and separately explicit.
- Bundle ID is durable identity; name/icon are presentation. Capture trigger
  app before HoldType UI changes frontmost state and freeze eligibility/folder
  ownership at dictation start.
- Unknown/untrustworthy trigger skips vlog without generic folder. HoldType
  windows are never implicit triggers.
- Readiness: Off, Setup required, Ready, Degraded camera, Degraded destination,
  or Degraded low storage.
