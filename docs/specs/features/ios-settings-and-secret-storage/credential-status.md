# iOS Credential Status And Reconciliation

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.credential-status@1`
- Read when: rendering or reconciling saved-key truth.
- Do not read when: only key-entry draft behavior matters.
- Maximum size: 100 physical lines.

Internal truth is not configured, not checked this process, saved last-known,
available this process, locked-unavailable, provider-rejected. UI reduces to
not connected, connected, needs attention. One secure row contains last-known
mask/replacement input—never second saved row. Connected has no check/banner;
`Try Again` only actionable attention, while rejection targets replacement.
Mutations communicate through field/status plus accessibility. Mask is no proof.
Label success `Saved in HoldType`; partial marker success warns status refresh.
Arbitrary errors reduce to closed categories. Primary status is never invented
from stale marker; not configured needs explicit removal or permitted resolution.

Before Keychain mutation atomically write marker `mutationInProgress`; failure
stops. After Security success write present/absent. Crash/final-write failure
leaves not-checked+refresh, never stale truth. Keychain failure restores exact
prior marker, else unknown; marker never rolls back/deletes successful key.
Security success remains user success despite final marker failure: update cache,
keep in-progress, warn. Previously missing marker restoration removes it.

Unreadable/corrupt/unsupported marker is byte-preserved; passive no Keychain;
save/remove stop before Security. Explicit refresh/preflight may resolve/cache
actual item but cannot overwrite bad marker and reports separate redacted issue.

Reconciliation skips write when already equal. Unknown/in-progress writes final.
Missing/contradictory first attempts unknown then final so failed final cannot
leave opposite truth; failed unknown preparation does not prevent final. Persist
redacted marker issue in process across passive/status/provider events until
successful reconciliation/mutation. Explicit result and revisioned stream
publish same update; presentation never reconstructs/weaken it.
