# Software Updates

## Goal

Define HoldType's native macOS software update behavior for direct
distribution outside the Mac App Store.

HoldType should be able to check for newer signed builds, present the update to
the user, download it through the native updater flow, and relaunch into the
installed version without requiring accounts, telemetry, or a custom backend.

## Scope

- automatic update checks
- manual Check for Updates command in Settings
- Settings controls for update preferences
- GitHub Releases as the update artifact host
- Sparkle appcast metadata and update signing
- direct-download DMG installation
- Homebrew Cask installation through a project-owned tap
- install-and-relaunch behavior

## Non-goals

- App Store updates
- account-based release channels
- custom update downloaders
- telemetry-backed rollout targeting
- local model, helper binary, or data-file update channels
- destructive cleanup, migration, or remote-storage release operations

## User-visible behavior

- HoldType should use a native macOS updater for direct distribution builds.
- GitHub Releases should provide a standard notarized disk image named
  `HoldType-<version>.dmg`.
- Opening the disk image should present `HoldType.app` and an Applications
  shortcut so the user can drag the app into `/Applications`.
- The first Homebrew distribution path should be a project-owned tap and cask,
  not a dependency on acceptance into the central Homebrew Cask repository.
- Homebrew installation should install the same notarized GitHub Release disk
  image as the direct-download path.
- Homebrew uninstallation may quit the running menu bar app before removal.
- `brew uninstall --zap` may remove HoldType-managed preferences, caches, and
  saved app state; ordinary Homebrew uninstall should not perform zap cleanup.
- Settings should include an Updates section that shows the current app version
  and build number.
- Settings should include a manual `Check for Updates...` command.
- Settings should include a `View Project on GitHub` link to the
  `holdtype/holdtype-swift` project page.
- Settings should let the user enable or disable automatic update checks.
- Settings should let the user enable or disable automatic update downloads
  when the updater supports them.
- Manual update checks should be available even when automatic checks are
  disabled.
- When an update is found, HoldType should present a native update prompt with
  the new version and release notes when they are available.
- Downloading and installing an update must be user-visible and cancellable
  through the updater UI where the updater supports cancellation.
- After an update is ready, HoldType may relaunch to install it. A
  user-confirmed updater relaunch must not be blocked by the normal quit
  confirmation dialog.
- Development or unsigned local builds may show that updates are unavailable or
  not fully configured, but they must not pretend to install production
  updates.

## Invariants

- HoldType must not implement its own unsigned app downloader or installer.
- Update artifacts must be signed for the updater and distributed from a stable
  HTTPS URL.
- Production update builds must be Developer ID signed and notarized before
  they are offered to users.
- The GitHub Release DMG is the canonical install artifact for both manual
  download and Homebrew Cask installation.
- Sparkle appcasts must point at final, published GitHub Release artifacts, not
  temporary CI upload URLs.
- Homebrew Cask metadata must include a concrete SHA-256 for each released DMG.
- Homebrew Cask zap cleanup must stay limited to HoldType-managed local
  preference/cache/state paths and must not remove user-created files by
  default.
- Update checks must not log API keys, transcripts, prompts, raw audio, or
  provider payloads.
- The updater must not add accounts, billing, telemetry, analytics, or
  server-side app state.

## Edge cases and failure policy

- If update metadata is unavailable, the app should show a recoverable updater
  error rather than blocking dictation.
- If the user cancels an update prompt, the app should keep running normally.
- If an update download fails, the app should keep the currently installed
  version and allow the user to check again later.
- If an update-triggered relaunch begins, HoldType should stop hotkey listening
  and transient session recovery exactly as it does for a normal confirmed
  termination, but it should skip the accidental-quit confirmation.
- If automatic checking is disabled, no background update check should be
  started by HoldType outside the updater's explicit manual check flow.

## Route / state / data implications

- The update appcast URL and updater public key live in the app bundle Info
  plist for production builds.
- User update preferences are non-secret local settings.
- Release tags use `v<version>` and GitHub Release artifacts use
  `HoldType-<version>.dmg`.
- A stable public appcast URL points to the latest signed update metadata.
- The release workflow may publish appcast metadata to GitHub Pages or another
  stable HTTPS host, but the URL must match the app bundle's `SUFeedURL`.
- The Homebrew tap lives outside the app bundle and should be updated from the
  release artifact SHA-256 after the GitHub Release is published.
- Version comparison uses the app bundle version and build number.
- Opening the GitHub project page from Settings is a user-triggered external
  browser action and must not change update preferences or start an update
  check.

## Verification mapping

- Unit coverage should verify local update preference persistence and Settings
  presentation labels.
- Build verification should confirm the Sparkle dependency links into the macOS
  target.
- Release verification should include code-sign validation, notarization
  validation, stapler validation, DMG assessment, SHA-256 generation, Homebrew
  cask audit for the published artifact, and a signed old build checking a test
  appcast, downloading a newer build, and relaunching into the new version.

## Unknowns requiring confirmation

- The final public owner/repository and appcast hosting URL.
- Whether the first production channel should ship universal builds or separate
  arm64/x64 artifacts.
- Whether the current `MACOSX_DEPLOYMENT_TARGET = 26.5` is the intentional
  first public minimum macOS version.
