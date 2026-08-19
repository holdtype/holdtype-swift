# Brownfield Source And Test Map

- Node type: leaf
- Status: Current resource
- Read when: locating likely implementation or test owners for a selected contract.
- Do not read when: product intent or current task status is being decided.
- Maximum size: 100 physical lines.

- `HoldType/HoldTypeApp.swift`, `MenuBarView.swift`: macOS entry/wiring/menu.
- `HoldType/SettingsView.swift`, `HoldType/Settings/`: settings sections.
- `FloatingIndicatorView.swift`, `FloatingIndicatorPanelController.swift`:
  indicator content/platform hosting.
- `HoldType/Models/`: settings/setup/dictation/output/usage/History models.
- `HoldType/Services/`: recording, request/provider, correction/translation,
  insertion, permissions, Keychain, hotkeys, diagnostics, cache, setup,
  History, runtime, and active context.
- `Shared/`: shared setup/status and containing-app startup seams; obsolete
  keyboard-session spike is retired after Brand Stage cutover.
- `HoldTypeTests/`: focused macOS service/model/presentation tests.
- `HoldTypeIOS/`, `HoldTypeIOSTests/`, and keyboard/shared packages: current
  scope only when selected by Active iOS contracts.

These are hints. Current checkout and targeted search establish actual ownership.
