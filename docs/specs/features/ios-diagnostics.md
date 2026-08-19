# iOS Diagnostics

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.diagnostics@1`
- Read when: local iOS app/keyboard support evidence, logs, or export matters.
- Do not read when: requesting telemetry, automatic upload, or system crash-file access.
- Maximum size: 100 physical lines.

## Scope and boundary

Final Settings Development section has Diagnostics & Support. It provides
bounded app-owned logs; redacted app/device/settings/audio/bridge summaries;
explicit Copy Recent Logs and Share Diagnostic File; locally delivered MetricKit
crash/hang evidence; and honest local failures.

No upload/telemetry/analytics/account support, system crash-file browsing/deletion,
broad device/Console logs, custom crash handler, or claim of iOS Analytics access.
Never store transcripts, prompts, dictionary, audio, keys, keystrokes, host identity,
provider content, or auto-upload diagnostics.

## Presentation and events

- Preserve four Settings destinations; Diagnostics is one final-section row.
- Show version/build, OS, device family, compact setup, mic authorization,
  audio phase, bridge schema/revision/expiry, and Full Access recently verified
  or not currently verified—never stale `disabled`.
- Runtime lines cover lifecycle/session/recording/provider/retry/claim/cache/export
  with stable typed categories and closed scalar allowlist only; no arbitrary
  dictionaries or punctuation-as-redaction.
- Delivery may correlate opaque request/claim/source/current/controller tags,
  never raw IDs/host/text. Distinguish insertion invocation, return, optional
  change observation, and claim ack; none proves visible/durable delivery.
- Project Voice stage only to closed content-free category, not enum serialization.
- Explicit Copy uses bounded visible redacted window. Explicit Share creates
  readable UTF-8 then system sheet, choosing no recipient/upload; include metadata,
  recent owned events, delivered crash/hang evidence, bridge health—no content/audio.
- Honest empty states: no delivered crash evidence does not mean no crash.
  Prelaunch failure recovery uses Xcode/TestFlight/App Store/user system evidence.

## Retention and storage

Runtime and delivered diagnostics are local, ≤7 days and ≤5 MB; bundle includes
≤48 hours runtime. Prune only HoldType files during normal use. Export exists only
for explicit action/user destination. App and extension each own separate App
Group cache files; neither appends to other's active file. Protected logs and
delivered diagnostics exclude backup. Export is derived local data, not bridge.

## Invariants and failures

Works without mic/Full Access/Keychain/OpenAI/live extension. Default logs are
short/redacted; verbose is opt-in/bounded and reset after investigation. macOS
generic formatting is not portable until typed and forbidden-value tested.
Never include insertion text or call an insertion delivered/successful from
return/change alone. Never mutate system diagnostics; MetricKit stays local and
does not replace store collection.

Unreadable logs still allow metadata-only export. Prune failure retries later
without unrelated deletion. Export failure reports and removes incomplete owned
artifact. Bridge failure shows category/schema only. Low storage affects export,
not History/recordings/settings/key.

## Verification

Test bounded append/order/caps/export selection; metadata-only and failed cleanup;
bad logs/bridge; MetricKit retention/empty/inclusion; every forbidden field;
opaque delivery formatting with no raw IDs/text/success claim; rejection of
arbitrary metadata; no Keychain/mic/provider/network. Manually verify system share.
