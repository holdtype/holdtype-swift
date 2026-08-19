# Software Updates

- Node type: hybrid
- Contract ID: `holdtype.macos.software-updates`
- Domain ID: `holdtype.macos.distribution`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released
- Contract revision: `holdtype.macos.software-updates@1`
- Read when: direct-build update checks, Sparkle, DMG/Homebrew artifacts, install/relaunch, or release verification is in scope.
- Do not read when: Mac App Store or iOS distribution is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Direct builds check, present, download, install, and relaunch signed updates
through a native updater without accounts, telemetry, custom backend/downloader,
or separate helper/data/model channels.

## Children

- [User update behavior](software-updates/user-update-behavior.md) — Settings, automatic/manual checks, prompt/download/relaunch, cancellation, and failure.
- [Artifacts and verification](software-updates/artifacts-and-verification.md) — canonical DMG, GitHub/appcast, Homebrew, signing/notarization, versioning, and release checks.

## Invariants

- Never implement an unsigned downloader/installer. Offered artifacts are
  Developer ID signed, notarized, update-signed, and served by stable HTTPS.
- The same canonical GitHub Release `HoldType.dmg` serves manual and Homebrew.
- Updater adds no account, billing, telemetry, analytics, or server state and
  logs no user/provider-sensitive content.
- Preferences are local/non-secret; development/unsigned builds report
  unavailable rather than pretending to install production updates.

## Dependency

- [Direct distribution decision](app-store-distribution.md) — current channel and Store prohibition.
