# Update Artifacts And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.software-updates@1`
- Clauses: `UPDATES.ARTIFACT`, `UPDATES.APPCAST`, `UPDATES.HOMEBREW`, `UPDATES.VERIFY`
- Read when: release artifact, appcast, Homebrew cask, signing, or update qualification is in scope.
- Do not read when: only in-app update UI is in scope.
- Maximum size: 100 physical lines.

- GitHub Releases publishes standard notarized `HoldType.dmg` without version
  suffix at `/releases/latest/download/HoldType.dmg`; DMG presents app plus Applications shortcut.
- Initial Homebrew path is project-owned tap/cask using that same artifact.
  Ordinary uninstall may quit app; only `--zap` removes bounded HoldType-managed
  preferences/cache/state, never user files by default.
- Release tags are `v<version>`. Production Info plist contains matching stable
  `SUFeedURL` and updater public key. Appcast points only to final published
  artifact; retained release-note URLs remain reachable.
- Cask pins concrete SHA-256. App minimum and cask both require macOS 14+.
- Verify final app/DMG: code sign, notarization, stapling, assessment, checksum,
  cask audit, DMG install, and signed-old-build test appcast download/relaunch.
- Appcast may use GitHub Pages/other stable HTTPS. Public owner/feed URL and
  universal versus split architectures remain open decisions.
