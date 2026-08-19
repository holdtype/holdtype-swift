# iOS Voice Safety And Verification

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.safety@1`
- Read when: failures, background capability, or acceptance evidence matters.
- Do not read when: only one normal action matters.
- Maximum size: 100 physical lines.

Invariants: no hidden recording; one capture/finalization/provider per attempt;
History playback/Retry arbitrated; Pending versus failed-row ownership never
double-presented; journal before provider; armed samples (historical) discarded;
network never keeps mic; no raw audio in bridge; waits bounded/cancellable;
failure never overwrites accepted text; stage order never resume position.

Missing setup/storage fails pre-capture. Empty/missing/oversize/unsupported not
uploaded; bounded unknown non-empty only explicit descriptor admission. Journal
failure preserves. Same-process Saved Recording visibility is required. Suspension
uses furthest durable exact action, never auto-upload. Interruption protects
bounded non-empty and reports interrupted; empty cleanup-only; max is normal Finish.
Changed/missing host disables auto insertion only.

P4 final plist has no audio background mode. Only isolated historical P6/M0C
spike could add it for explicitly foreground-started Quick Session, never network/
extension. Inspect plist/entitlements/indicator/Stop/expiry; reliability/battery/
review failure removes capability and leaves foreground complete.

Verify single shared owners/passive construction; two-scene/prompt/loss/no-resume;
ordered preflight/short-circuits/revalidations/playback handoff; timers/actions/
journal/provider/late results; complete launch repair/reconciliation and no
external side effects; all phases/recovery variants; Simulator presentation;
physical transitions/force quit/lock/calls/Siri/alarms/Bluetooth/media reset/Low
Power/battery and provider without mic; build capability isolation. Record physical
passes with device/OS/state/expectation/result/gate. Live Activity remains unknown
and never background execution.
