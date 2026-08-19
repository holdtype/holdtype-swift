# Permission States, Failures, And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clauses: `PRIVACY.STATE`, `PRIVACY.FAILURE`, `PRIVACY.VERIFY`
- Read when: permission state modeling, blocked recovery, data ownership, or acceptance is in scope.
- Do not read when: only disclosure wording or signing is in scope.
- Maximum size: 100 physical lines.

## State and failure

- Microphone: `allowed`, `denied`, `not determined`, `unavailable`. Query never
  records/creates audio; production request uses callback, tests use a fake.
- Accessibility: `trusted` or `not trusted`. Input Monitoring: `allowed`,
  `denied`, or `not determined`.
- Denied/policy-restricted permission shows recoverable blocking, never repeated prompts.
- First mic failure without prompt/listing first triggers installed-artifact entitlement triage.
- Provider failure visibly ends the current attempt and permits later retry.
- Crash/interruption leaves no undocumented audio: cache controls expose it or cleanup removes it.
- Temporarily enabled debug logging is disabled after investigation.

## Data implications

Permission/AX/Input states are available to recording and output/context flows.
Launch-at-login comes from Login Items and is not readiness. Provider settings
affect behavior; ordinary settings may use UserDefaults but keys use Keychain
and process cache. Audio owners are explicit cache, bounded retry, or Dev Vlogs.
Runtime diagnostics are local derived data, separate from History/audio/crash reports.

## Verification and unknowns

Cover first launch, deny/grant-after-denial/unavailable mic; disclosure and
setup routing; redaction of logs and exports; TCC identity/entitlements on the
actual artifact; bounded refresh; no Keychain prompts; and menu fallback when
Input Monitoring is denied.

Open questions: formal onboarding before first recording; temporary Debug audio
retention; and exact placement/wording for OpenAI audio and nearby-context copy.
