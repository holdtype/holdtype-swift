# Keyboard Handoff Privacy And Release

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-handoff.release@1`
- Read when: shared-state privacy, fallback, or release acceptance matters.
- Do not read when: only local keyboard composition matters.
- Maximum size: 100 physical lines.

Extension never records/links microphone/provider. App owns permission, audio,
OpenAI, acceptance. Lower services may be reused, never ordinary Voice controller,
scene/presentation/recovery. Full Access may enable bounded coordination; local
editing remains. Shared expiring state contains voice coordination, safe Fix
metadata, one Fix pair—never audio/key/provider/custom prompt/durable History.
No error auto-resubmits audio.

Complete flow requires signed iPhone; Simulator cannot prove ownership/switching/
recreation/App Review. TestFlight/App Review are gates, not reasons to remove
handoff. If rejected with no compliant equivalent, ship app-only without
extension/onboarding/dead controls—never manual-session keyboard. Temporary app
session controls may qualify only, never become production entry.

Acceptance proves microphone cold start without prep; sheet isolation/truthful
phases/blockers/saved recovery; recreated reconnect; Quick Insert/Auto stability;
same app recording Finish/sheet Cancel; at-most-once insertion under exact
active-visible request/destination proof; durable capture control but no unsafe
destination; repeated warm attempts; 60 s idle independent of capture/provider;
limit Pending/play/provider once; host/process uncertainty preserves Latest;
correct sheet versus keyboard failure ownership; actionable Translation route;
selected Fix exact-once and no-selection unavailable absent signed qualification;
and clean app-only exclusion preserving standalone Voice.
