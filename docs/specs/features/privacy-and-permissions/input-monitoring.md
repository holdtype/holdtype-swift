# Input Monitoring Permission

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clause: `PRIVACY.INPUT-MONITORING`
- Read when: global-hotkey key observation, TCC registration, status, or recovery is in scope.
- Do not read when: a Fix is already invoked or only Accessibility is in scope.
- Maximum size: 100 physical lines.

- Explain/request Input Monitoring only when native global hotkey listening
  outside HoldType needs it. Menu recording remains available when required setup is complete.
- It is not required for a Fix already invoked through an available path.
- State is `allowed`, `denied`, or `not determined`; only a fresh HID listen-event
  status decides allowed. Probe success/CoreGraphics success alone does not.
- Action first asks macOS to register via HID listen-event request and short
  bounded HID manager open, plus bounded CoreGraphics request, event-tap, and
  AppKit global-monitor probes, then opens the pane.
- If this process already read AX, it may launch a fresh one-shot instance of
  the same bundle that performs Input Monitoring before AX. That instance
  activates as a regular foreground app, briefly waits on main run loop, makes
  only this request, and runs no dictation/hotkey/clipboard/setup/cleanup/provider work.
- Debug reset is opt-in, limited to `app.holdtype.HoldType` listen-event entry,
  then launches canonical Debug app to request registration.
- If still absent after relaunch/retry, manual `+` is fallback; never promise or
  force a TCC row or edit TCC databases.
- After two unsuccessful actions, elevate visible warning: click `+`, choose the
  running `HoldType.app`, enable it. Reset warning when status becomes allowed.
