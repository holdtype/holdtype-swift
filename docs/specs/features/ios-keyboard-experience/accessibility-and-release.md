# Keyboard Accessibility And Release

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-experience.release@1`
- Read when: accessibility/appearance or qualification evidence matters.
- Do not read when: only functional transport semantics matter.
- Maximum size: 100 physical lines.

VoiceOver names Quick Insert, Auto/modes, Fixes, History, microphone state/action,
Latest, Globe, Space, Delete, Return. States never color-only. Increase Contrast
strengthens boundaries; Reduce Transparency uses opaque system colors; Reduce
Motion keeps complete static cyan/purple wave silhouettes. Light/Dark geometry
identical; neutral rails/utilities/editing share one base key color. Same-phase
rerender must not rebuild art/restart motion/move accessibility focus/flash;
only phase/size/lifecycle/Reduce Motion change updates once.

KBD-MVP-2 split: signed iPhone + DEBUG app controls prove recorder/Finish/Cancel/
expiry/idle release without Mirroring keyboard; record indicator when wired
surface exposes it, otherwise report unavailable. Simulator/tests prove extension,
bounded reduction, insertion, restricted editing. This does not replace final matrix.

Automated/Simulator prove composition/appearances/no manual copy/local editing/
state reduction/stale rejection/bounded decode/one insertion/Latest fallback/
always-available Quick Insert+Auto/stable render, plus Fix metadata/workspace/
selection/expiry/exactly-once fake replacement.

Signed device proves signing/App Group with access on/off; no extension Settings/
launch; app session lifecycle; Start/Finish/Cancel/ack/timeout/real-host insertion;
background/interruption/Low Power/eviction/privacy indicator; no auto-insert after
host/owner change; explicitly authorized live mic→OpenAI→host smoke; selection
Fixes in representative hosts; complete-field only where exact traversal/replacement
proven, otherwise refusal. TestFlight waits for device evidence; Simulator/
competitor behavior never implies App Store approval.
