# Permission Setup And Credential Gating

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clauses: `PRIVACY.SETUP`, `PRIVACY.CREDENTIAL`
- Read when: launch setup, recording preflight, Settings routing, or credential readiness is in scope.
- Do not read when: only permission registration mechanics or disclosure is in scope.
- Maximum size: 100 physical lines.

## Launch and deferral

- Missing/denied/unavailable required permission opens full Settings focused on
  Permissions with warning, but launch never records or auto-prompts.
- Closing Settings defers only the visible surface for this run; it grants
  nothing, bypasses nothing, and does not advance to API-key setup.
- Explicit setup-dependent actions may reopen Permissions.
- A first recording attempt with microphone `not determined` uses the native
  prompt first; allow continues normal checks, deny remains inactive and opens setup.
- Launch never reads Keychain or automatically opens OpenAI Settings.

## Ordered recording preflight

- Every start rechecks setup. Denied/unavailable microphone or missing AX trust
  required by enabled output/context opens Permissions and stays inactive.
- Only after permission blockers clear, evaluate API-key readiness. Missing,
  unavailable, or unauthorized key opens OpenAI Settings with warning before capture.
- Menu bar has no duplicate permission status/recovery block; the action routes
  first-time mic to native prompt and other permission blockers to Settings.
- Accessibility absence may still permit transcription when insertion/context
  are not required; nearby context is then omitted and no clipboard fallback occurs.

## Credential boundary

- Keychain readiness is provider setup, never a permission.
- Recording requires the key already loaded into the process without Keychain
  authentication UI. If cache is empty on explicit recording request, one lazy
  resolution is allowed; failure/no key opens OpenAI setup before capture.
- Closing OpenAI Settings changes no key state. Passive launch, permission
  refresh, recording readiness, and Settings polling never read secure storage.
- Keychain authentication UI is allowed only immediately after explicit save or
  replace in OpenAI Settings. Key status never reveals/logs/persists the key
  outside Keychain, process cache, or the explicit Debug exception.
