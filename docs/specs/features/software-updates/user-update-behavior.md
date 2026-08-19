# User Update Behavior

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.software-updates@1`
- Clauses: `UPDATES.SETTINGS`, `UPDATES.FLOW`, `UPDATES.FAILURE`
- Read when: update preferences, checks, prompt, download, install, cancel, or relaunch is in scope.
- Do not read when: only release artifact publication is in scope.
- Maximum size: 100 physical lines.

- Updates shows current version/build, manual `Check for Updates...`, project
  GitHub link, automatic-check toggle, and automatic-download toggle when supported.
- Manual checks work when automatic is off; disabling automatic starts no
  background check outside explicit manual flow.
- Found update uses native prompt with version/release notes. Download/install
  is visible and cancellable where supported. Cancel keeps app running; metadata/
  download failure is recoverable and keeps current version.
- User-confirmed updater relaunch bypasses normal accidental-quit confirmation.
  Stop hotkey/transient recovery as normal confirmed termination, but first
  request bounded active-capture finalization; journaled positive-byte source
  stays recoverable if updater deadline ends the process.
- Project-link action changes no preference and starts no update.
