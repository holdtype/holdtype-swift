# Menu Bar Lifecycle and Presentation

- Node type: leaf
- Contract ID: `holdtype.macos.menu-bar-shell.lifecycle`
- Domain ID: `holdtype.macos.menu-bar-shell`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.menu-bar-shell.lifecycle@1`
- Read when: process presence, Dock behavior, menu presentation, app windows, or quit behavior is in scope.
- Do not read when: only command availability or compact recording status is in scope.
- Maximum size: 100 physical lines.

## Presence and presentation

- HoldType runs as a macOS menu bar app, and its status item remains available
  while the process is running.
- `DOCK-1`: HoldType has no Dock icon by default; the menu bar item is its
  primary persistent presence.
- `DOCK-2`: `Show HoldType in Dock` changes Dock presence immediately and
  persists across launches.
- `DOCK-3`: With Dock presence disabled, Settings, Transcript History, Manage
  Fixes, Dev Vlogs, recovery prompts, and quit confirmation still present in
  front when requested. Opening or closing them never changes the preference.
- The status item uses the branded template asset `HoldTypeMenuBarIcon`, has no
  visible text title, accessibility label `HoldType`, and help text
  `HoldType Dictation`.
- The compact surface is a native SwiftUI `MenuBarExtra` using window style.
  Escape, an outside or other-app click, and a second status-item click dismiss
  it through standard macOS behavior without retaining invisible focus.
- Opening the menu surface does not capture or retain an external Fixes target.

## Window independence

- Settings, Transcript History, and Dev Vlogs window state is separate from
  recording state. Opening, closing, or navigating these windows does not
  start, stop, cancel, or otherwise affect ordinary dictation.
- Only a later eligible explicit dictation action may start the independently
  owned Dev Vlogs branch.
- Closing Settings, Transcript History, or another ordinary HoldType window
  neither asks for quit confirmation nor terminates HoldType.
- Closing an ordinary window preserves the configured Dock presence rather
  than unconditionally changing activation policy.

## Quit behavior

- Menu Quit, application-menu Quit, Dock Quit, and `Command+Q` require
  confirmation before termination.
- Menu-bar Quit first dismisses the compact surface, then presents the
  confirmation as the frontmost key prompt rather than behind another window.
- The confirmation contains only the direct question and its actions; it adds
  no explanation about shortcuts, menu-bar actions, launch at login, or Right
  Command availability.
- Transient quit prompts retain the compact native macOS dialog hierarchy: one
  accent-colored affirmative default and a subdued Cancel action, without
  generic equal-weight buttons or exposed window chrome.
- Updater-initiated relaunches bypass quit confirmation; detailed behavior is
  owned by [Software updates](../software-updates.md).
- Cancel keeps the app, status item, shortcuts, and future dictation available.
  Confirm terminates the app cleanly.

## Failure and restart policy

- If Settings cannot open, show a clear recoverable error.
- Restarting macOS does not itself make global shortcuts available. HoldType
  must be running because the user opened it or approved launch at login in
  macOS Login Items.

## Dependencies

- [Menu bar app shell](../menu-bar-app-shell.md) — shared scope and invariants.
- [Software updates](../software-updates.md) — updater relaunch behavior.
