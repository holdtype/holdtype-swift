# Historical Containing-App Safety And Gates

- Node type: leaf
- Status: Historical
- Read when: reviewing old Quick Session/device-gate and failure evidence.
- Do not read when: activating Quick Session or legacy History.
- Maximum size: 100 physical lines.

Quick Session was gated five-minute exploration with explicit foreground start,
disclosure, visible mic/time/Stop, discarded armed samples, manual host return,
and deterministic expiry/interruption/termination. Failure retained one-shot and
manual insertion. It is not current.

Protected invariants: app alone owns mic/provider/secrets/stores; extension gets
no sensitive state; no passive recording; Full Access ≠ mic; no seamless-return
promise/inert controls/parallel scene sessions/content logs. Failures preserved
results, distinguished setup owners, reconciled relaunch, treated heartbeat stale
honestly, and blocked shell on unavailable storage.

Historical routes separated setup destinations from app surfaces and kept
Latest/History/Pending/bridge lifetimes independent. Verification covered shell/
scene restoration/setup/no-launch work/one-shot/cancel/recovery/no external
insertion/multiscene, with physical keyboard/Full Access/background/manual return/
interruption/expiry/force quit/host limits. Quick Session, QWERTY, iPad keyboard,
Live Activity/layouts required later decisions and never self-activated.
