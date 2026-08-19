# Permission Signing And Debug Identity

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clause: `PRIVACY.IDENTITY`
- Read when: release entitlements, TCC identity, signing, debug path, or sandbox is in scope.
- Do not read when: only permission UI copy or state routing is in scope.
- Maximum size: 100 physical lines.

- TCC identity shown to users resolves to `HoldType`; MVP bundle ID is
  case-sensitive `app.holdtype.HoldType` because row recreation may use metadata.
- Bundle includes `NSInputMonitoringUsageDescription` explaining global
  shortcuts; omission may prevent a System Settings row.
- Shipped signed/notarized artifact—not merely project/Debug—must contain
  Hardened Runtime `com.apple.security.device.audio-input`. Prompt denial with
  no Microphone row is an entitlement/signing defect until artifact proof exists.
- Permission QA uses stable identity across rebuilds: Apple Development when
  configured. Ad-hoc cdhash-only identity is forbidden; stable local requirement
  is iteration fallback, not proof of Input Monitoring registration.
- Shared scheme/run script launch the canonical default Xcode Debug product
  unless explicitly using isolated `HOLDTYPE_DERIVED_DATA_PATH`. Another app
  path creates another TCC row and is not evidence that current status is stale.
- The macOS MVP is not App Sandbox while insertion, Paste Last Result, or nearby
  context relies on AX control. This also excludes current Mac App Store release.
  Re-enabling sandbox requires replacement architecture and proof AX registration remains.
