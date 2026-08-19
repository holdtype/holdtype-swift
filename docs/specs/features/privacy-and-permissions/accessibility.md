# Accessibility Permission

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clause: `PRIVACY.ACCESSIBILITY`
- Read when: AX trust, active-app insertion/context, stale rows, or AX recovery is in scope.
- Do not read when: only microphone or Input Monitoring behavior is in scope.
- Maximum size: 100 physical lines.

- Explain Accessibility when insertion or Paste Last Result needs active-app
  control. Default status query is non-prompting `AXIsProcessTrusted()`.
- The next action actively requests trust before/alongside opening System Settings;
  do not merely deep-link to an empty list.
- `trusted` permits active-app control; `not trusted` blocks insertion/paste and
  nearby-context capture, but transcription may continue. Never use system clipboard fallback.
- If missing, explain enable/add running HoldType. If a visible toggle is on but
  runtime remains untrusted, explain stale-copy recovery: remove old row,
  request from running app, enable the new row, and possibly quit/reopen.
- Status always reflects the running app, never a row belonging to another path
  or code requirement. After action, bounded polling may update Settings in place.
- Debug AX reset is explicit and limited to the `app.holdtype.HoldType` service
  entry, then launches canonical Debug app and requests trust from that app.
- Permission reads/requests must handle Input Monitoring first in a process;
  earlier AX reads can prevent HID registration refresh.
- Automatic insertion and Paste Last Result show clear failure when a surface
  exists. Nearby context is simply omitted while normal prompt/dictionary remain.
