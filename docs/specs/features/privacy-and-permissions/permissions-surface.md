# Permissions Settings Surface

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clause: `PRIVACY.PERMISSIONS-SURFACE`
- Read when: Permissions Settings content, warnings, actions, or refresh is in scope.
- Do not read when: only provider disclosure or low-level TCC registration is in scope.
- Maximum size: 100 physical lines.

## Content boundary

- Permissions is exclusively status/request UI for Microphone, Accessibility,
  and Input Monitoring, with product-language status and bounded request/open-pane actions.
- It contains no application toggles, consent/default gates, OpenAI/Fixes copy,
  API-key status/link, or correction/translation/audio disclosures.
- Launch at login is availability, not required TCC: it never blocks recording
  or enters setup warnings. It may appear as a recommended item sharing the
  Behavior control and, when macOS needs approval, an approval action.
- Input Monitoring is optional unless an enabled production hotkey path needs
  it; its absence alone never opens required launch setup.

## Refresh and warning behavior

- After a permission prompt/action, refresh and keep setup visible while other
  required items remain. Allowed items leave the actionable warning.
- On Permissions visibility, app activation, or Settings becoming key, request
  a fresh snapshot. While visible, lightly poll microphone, AX, and Input
  Monitoring both directions; never include Keychain.
- Settings changes affecting required setup immediately recompute from a fresh snapshot.
- Resolving one permission cannot dismiss remaining setup.
- The warning never checks/displays/links API-key or Fixes consent state.

## Product exclusions

The MVP surface does not expose analytics, cloud backup, local-model management,
system-audio capture, or reference-app raw-audio controls. Cache retention is
owned by its explicit storage surface.
