# iOS V1.1 Release Gates

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.gates@1`
- Read when: claiming V1.1 release readiness or choosing required evidence.
- Do not read when: implementing an isolated capability without release claim.
- Maximum size: 100 physical lines.

## Automated and Simulator

Require green macOS; iOS Debug/Release with embedded extension; app/extension
isolation; fake Voice→Latest; Pending relaunch; Rules/Settings persistence;
History append/Copy/swipe Delete/Clear/cap/failure isolation with no detail,
Share, date, or time; cache defaults/policies/retention/reconciliation/Play and
playback→Voice; no placeholder; production tab order Voice, Rules, History,
Usage, Settings with no qualification root.

Keyboard tests cover both appearances, no retired manual-session copy, central
states, punctuation, Delete repeat, Space cursor, Return traits, honest session,
bounded decoding, stale rejection, one History-derived Latest, auto-insertion
ownership, explicit Latest, Fixes projection/range replacement, expiry, and
stale-document rejection.

## Signed physical iPhone

KBD-MVP-2 may split physical app-recorder controls from Simulator keyboard
evidence per `docs/ios-keyboard-dictation-mvp-plan.md`; that does not waive this gate.

A recorded device pass proves:

- matching signed app/extension/App Group; keyboard enablement and Globe;
- punctuation/editing in Notes, Messages, Mail, Safari, and two third-party apps;
- selected-text Fix exact replacement with no mutation after focus/selection/
  source change; no-selection only after complete traversal/exact replacement,
  otherwise fail closed;
- restricted editing and supported read-only Latest with Full Access off; one-
  writer command/state with it on; secure/phone/opt-out fallback;
- no extension Settings/app-launch button or private Settings workaround;
- cold handoff, warm availability, expiry/reuse; Start, acknowledged Listening,
  Finish, Cancel, Processing, timeout, and one owned-context accepted insertion;
- background/interruption/Low Power/eviction without silent keepalive or idle
  capture; foreground Done/Cancel/interruption/provider timeout;
- rejected auto insertion after extension restart, host change, or expiry, with
  Latest safe fallback; termination preserves Latest or one Pending;
- effective Keychain and Data Protection;
- after explicit user authorization and configured key, one manual Standard
  microphone→OpenAI→rules→Latest→History→same-request insertion smoke. Agents
  never enter the key or run live-provider tooling absent that request.

Simulator cannot pass. Release has no keyboard History/Settings launch; local
editing and explicit Latest are independently useful. Keyboard dictation is a
no-go until signed-device background round trip plus privacy/energy pass.
Competitor behavior is not evidence.
