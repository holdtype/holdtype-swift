# First Release Runbook

This runbook turns the tracked release automation into a real public release.
It assumes the release contract in `docs/release/software-updates.md`.

Do not commit certificates, API keys, Sparkle keys, or generated private key
files. Store them only in GitHub repository secrets or local untracked files.

## 1. Confirm Public Release Choices

Before creating the first public tag, decide:

- the final GitHub owner/repository URL;
- the appcast URL used by `HOLDTYPE_UPDATE_FEED_URL`;
- whether GitHub Pages is the appcast host;
- the first public minimum macOS version, currently macOS 14 Sonoma;
- whether the first artifact is Apple Silicon only or a universal build;
- the project-owned Homebrew tap repository, for example
  `holdtype/homebrew-tap`.

The Xcode project must report `MACOSX_DEPLOYMENT_TARGET = 14.0`. If the public
minimum changes later, update the project setting, release preflight guardrail,
and Homebrew cask `depends_on macos:` value together.

## 2. Prepare Apple Signing And Notarization

Required Apple-side material:

- Developer ID Application certificate exported as a password-protected `.p12`;
- Apple Team ID;
- App Store Connect API key with notarization access;
- API key ID;
- API issuer ID.

Convert the `.p12` certificate to a GitHub secret value:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Add these repository secrets:

```text
APPLE_TEAM_ID
DEVELOPER_ID_CERTIFICATE_BASE64
DEVELOPER_ID_CERTIFICATE_PASSWORD
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_PRIVATE_KEY
```

`APP_STORE_CONNECT_PRIVATE_KEY` should contain the full `.p8` file contents.

## 3. Prepare Sparkle Signing

Generate or locate the Sparkle EdDSA key pair. The public key must be compiled
into production builds as `HOLDTYPE_UPDATE_PUBLIC_ED_KEY`; the private key is
used only by release automation to sign the appcast.

Add these repository secrets:

```text
SPARKLE_EDDSA_PRIVATE_KEY
HOLDTYPE_UPDATE_PUBLIC_ED_KEY
HOLDTYPE_UPDATE_FEED_URL
```

If GitHub Pages hosts the appcast, use a stable URL such as:

```text
https://<owner>.github.io/holdtype-swift/appcast.xml
```

## 4. Enable GitHub Pages

In the GitHub repository settings:

1. Open Pages settings.
2. Set the source to GitHub Actions.
3. Confirm Actions can create deployments.

The release workflow publishes one complete Pages artifact containing the
static product landing, `appcast.xml`, and every versioned release-notes file
referenced by that appcast. The standalone Pages workflow rebuilds the same
complete artifact from the latest stable GitHub Release when landing files
change. Both workflows share one queued publication lock so neither deployment
can replace the site with only part of the required files.

After secrets and Pages are configured, run the read-only setup verifier before
creating the first tag:

```sh
GITHUB_TOKEN=<token-with-actions-secrets-variables-and-pages-read-access> \
scripts/release/verify_github_release_setup.py \
  --repository holdtype/holdtype-swift \
  --appcast-url https://holdtype.github.io/holdtype-swift/appcast.xml \
  --expected-homebrew-tap holdtype/tap \
  --require-homebrew-tap \
  --require-homebrew-minimum-macos
```

## 5. Prepare The Homebrew Tap

Create the tap repository, for example:

```text
holdtype/homebrew-tap
```

Homebrew maps the public tap name `holdtype/tap` to the GitHub repository
`holdtype/homebrew-tap`. Configure `HOMEBREW_TAP_REPOSITORY` with the GitHub
repository name, not the shortened tap name.

The tap repository must be public and not archived before the release workflow
opens tap pull requests. The setup verifier checks this repository through the
GitHub API when `HOMEBREW_TAP_REPOSITORY` is configured.

Add an empty `Casks/` directory or let the release workflow create it in the
tap update branch. The release workflow resolves the tap repository's default
branch through the GitHub API and uses that branch as the pull-request base.

Add this repository variable to the app repository before the first public
release:

```text
name: HOMEBREW_TAP_REPOSITORY
value: holdtype/homebrew-tap
```

Add the expected public tap prefix as a separate guardrail. The release
preflight compares this value with the prefix derived from
`HOMEBREW_TAP_REPOSITORY`, so a personal `homebrew-tap` repository cannot
accidentally ship as the wrong public tap:

```text
name: HOMEBREW_EXPECTED_TAP
value: holdtype/tap
```

Create a GitHub token that can clone the tap, push a branch, and open a pull
request. Add this secret to the app repository before the first public release:

```text
HOMEBREW_TAP_TOKEN
```

Add this repository variable before the first public release. The value must
match the public support boundary:

```text
name: HOMEBREW_MINIMUM_MACOS
value: >= :sonoma
```

Leave official Homebrew Cask bump automation disabled for the first release.
After the initial `holdtype` cask is accepted into `Homebrew/homebrew-cask`,
run the setup verifier with the official cask gate:

```sh
GITHUB_TOKEN=<token-with-actions-secrets-variables-and-pages-read-access> \
scripts/release/verify_github_release_setup.py \
  --repository holdtype/holdtype-swift \
  --appcast-url https://holdtype.github.io/holdtype-swift/appcast.xml \
  --expected-homebrew-tap holdtype/tap \
  --require-homebrew-tap \
  --require-homebrew-minimum-macos \
  --require-official-homebrew-cask
```

This verifier decodes the upstream `Casks/h/holdtype.rb` file and checks that
the short command is backed by the HoldType cask token, GitHub Release DMG URL,
`HoldType.app` artifact, pinned numeric version, pinned SHA-256, and no
`version :latest` or `sha256 :no_check` fallback.

Then add a `HOMEBREW_GITHUB_API_TOKEN` repository or environment secret and set
this repository variable:

```text
name: HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED
value: true
```

Optionally set `HOMEBREW_OFFICIAL_CASK_FORK_ORG` to the GitHub owner or
organization that should own the `brew bump-cask-pr` fork.

The first public Homebrew install command will be:

```sh
brew tap holdtype/tap
brew trust holdtype/tap
brew install --cask holdtype
```

The shorter command:

```sh
brew install --cask holdtype
```

becomes available to new users only after the cask is accepted into
`Homebrew/homebrew-cask` with the `holdtype` token. Treat that as a follow-up
distribution milestone after the GitHub Release DMG is public, versioned,
notarized, and stable.

After a release DMG exists, the tap cask can be updated manually with:

```sh
scripts/release/update_homebrew_tap.sh \
  --tap-dir /path/to/homebrew-tap \
  --version 1.0.0 \
  --sha256 <sha256-of-HoldType.dmg> \
  --repository <app-owner>/holdtype-swift \
  --tap-repository holdtype/homebrew-tap \
  --audit
```

The script only updates and optionally audits `Casks/holdtype.rb`; it does not
commit, push, or create the tap pull request.

The rendered cask should quit `app.holdtype.HoldType` during Homebrew uninstall
and include optional zap cleanup for:

```text
~/Library/Caches/HoldType
~/Library/Preferences/app.holdtype.HoldType.plist
~/Library/Saved Application State/app.holdtype.HoldType.savedState
```

Zap cleanup is user-triggered with `brew uninstall --zap`; ordinary Homebrew
uninstall should leave these local support files alone.

When preparing the later official Homebrew Cask PR, render the candidate into a
local `Homebrew/homebrew-cask` checkout or fork. The helper verifies that the
candidate is written to the official `Casks/h/holdtype.rb` layout and that the
cask metadata points at the public GitHub Release DMG:

```sh
scripts/release/prepare_official_homebrew_cask.sh \
  --homebrew-cask-dir "$(brew --repository homebrew/cask)" \
  --version 1.0.0 \
  --sha256 <sha256-of-HoldType.dmg> \
  --repository <app-owner>/holdtype-swift \
  --minimum-macos ">= :sonoma" \
  --audit
```

The official cask helpers require this minimum macOS value. Use the same
Homebrew comparison expression that you configured as `HOMEBREW_MINIMUM_MACOS`.

To inspect a rendered candidate directly without changing it:

```sh
scripts/release/verify_homebrew_cask.py \
  --cask-path "$(brew --repository homebrew/cask)/Casks/h/holdtype.rb" \
  --version 1.0.0 \
  --sha256 <sha256-of-HoldType.dmg> \
  --repository <app-owner>/holdtype-swift \
  --minimum-macos ">= :sonoma" \
  --official-layout
```

To create the actual upstream PR branch after the public DMG is live and the
official cask submission is intentionally starting, prefer the uploaded
submission bundle wrapper. It reads `metadata.json`, prepares the local
`homebrew/cask` checkout with `brew tap --force homebrew/cask` when needed, and
then creates the PR branch from the verified release metadata:

```sh
scripts/release/open_official_homebrew_cask_pr_from_bundle.sh \
  --bundle-dir /path/to/holdtype-official-homebrew-cask-1.0.0 \
  --audit \
  --style \
  --fork-repository <github-user>/homebrew-cask \
  --push \
  --open-pr
```

Use the lower-level helper directly only when you intentionally want to pass
the version, SHA-256, repository, and minimum macOS values yourself:

```sh
scripts/release/create_official_homebrew_cask_pr.sh \
  --homebrew-cask-dir "$(brew --repository homebrew/cask)" \
  --version 1.0.0 \
  --sha256 <sha256-of-HoldType.dmg> \
  --repository <app-owner>/holdtype-swift \
  --minimum-macos ">= :sonoma" \
  --audit \
  --style \
  --fork-repository <github-user>/homebrew-cask \
  --push \
  --open-pr
```

The script creates the local commit first. It only pushes or opens the
`Homebrew/homebrew-cask` pull request when `--push` and `--open-pr` are passed.

After the cask is accepted, later releases should use Homebrew's cask bump PR
flow instead of the new-cask helper:

```sh
scripts/release/bump_official_homebrew_cask_pr.sh \
  --version 1.0.1 \
  --sha256 <sha256-of-HoldType.dmg> \
  --repository <app-owner>/holdtype-swift
```

The bump helper prepares the official `homebrew/cask` tap locally with
`brew tap --force homebrew/cask` before calling `brew bump-cask-pr`, so it works
on fresh CI runners as well as developer machines.

The release workflow can run the same bump automatically when
`HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED=true` and `HOMEBREW_GITHUB_API_TOKEN` is
configured. Do not enable it before the first upstream cask is merged and
`verify_github_release_setup.py --require-official-homebrew-cask` proves that
`Homebrew/homebrew-cask` already contains `Casks/h/holdtype.rb`.

## 6. Local Preflight

Run the non-publishing preflight from the app repository:

```sh
scripts/release/preflight.py
```

This includes a release-workflow wiring check, so changes to
`.github/workflows/release.yml` should fail locally if a required build,
appcast, published-release, or Homebrew tap step is removed or moved out of
order.

Expected local warnings:

- release secrets are absent from the shell unless you intentionally exported
  them;
- Homebrew tap configuration and token are absent unless you intentionally exported
  `HOMEBREW_TAP_REPOSITORY`, `HOMEBREW_EXPECTED_TAP`, and
  `HOMEBREW_TAP_TOKEN`.

No `fail` checks should remain.

The GitHub Actions release workflow runs the stricter form:

```sh
scripts/release/preflight.py --require-secrets --require-homebrew-tap --json
```

That means `HOMEBREW_TAP_REPOSITORY`, `HOMEBREW_EXPECTED_TAP`,
`HOMEBREW_TAP_TOKEN`, and `HOMEBREW_MINIMUM_MACOS` must be configured before a
public release run can publish, so Homebrew tap publication is not accidentally
skipped or pointed at the wrong public tap.

Validate the exact release inputs before creating the tag or using manual
workflow dispatch:

```sh
scripts/release/validate_release_inputs.py \
  --version 1.0.0 \
  --build 1 \
  --tag v1.0.0 \
  --release-dir dist/release/v1.0.0 \
  --download-url-prefix https://github.com/<app-owner>/holdtype-swift/releases/download/v1.0.0/
```

Optionally build a local preview DMG to validate packaging before release
secrets are configured:

```sh
scripts/release/build_preview_dmg.sh --version 1.0.0 --build 1
```

The preview DMG is not notarized and must not be published. It is useful only
for checking the Release build, Sparkle plist keys, DMG layout, DMG copy/install
path, ZIP, checksum, and preview manifest.

If you use `scripts/release/build_release.sh --skip-notarization` to validate
the archive/export path before notarization credentials are ready, treat that
output the same way: it is verification-only. Its `release-manifest.json` uses
`kind: notarization-skipped-release`, `notarized: false`, and
`public_release: false`, so it must not be uploaded to GitHub Releases, Sparkle,
or Homebrew.

## 7. Create The Release

For recurring releases, use the next patch version by default. Choose a minor
or major version only when an explicit product/release decision identifies a
substantial backward-compatible milestone or a breaking release; a collection
of ordinary fixes and incremental features does not by itself require a minor
version.

Prepare and validate the release on `master`:

1. Confirm that the intended product changes have already completed their
   development checks. Publication does not run, rerun, or wait for tests, and
   current test status is not a publication gate after the user says to
   publish.
2. Add `docs/release/notes/<version>.md` with a matching
   `# HoldType <version>` heading and an accurate summary of changes since the
   last published release.
3. Validate the notes and exact version/build/tag inputs.
4. Commit the release notes with the intended product state and push `master`.
5. Dispatch the `Release` workflow from the pushed `master` SHA through the
   authenticated GitHub CLI with the explicit version and build values.

The Release workflow performs packaging and artifact-integrity verification:
version inputs, signing, entitlements, notarization, checksums, DMG install,
appcast, and published channels. Those checks protect the distributable and
must not be replaced with or expanded into product test execution during
publication.

The current `github-pages` environment protection admits `master` but rejects
tag refs. Therefore the normal recurring path is `workflow_dispatch` from
`master`, not pushing the tag first. The release workflow derives
`v<version>` from the version input and creates that tag at the dispatched
`master` SHA when it publishes a new GitHub Release. If the exact tag already
exists, the workflow verifies it before publishing instead.

### Dispatch With The GitHub CLI

Safari and Computer Use are not part of the release path. Install and
authenticate the GitHub CLI once on the release machine, then use it for every
dispatch, status check, and post-release inspection.

1. Verify that the CLI is available. If it is missing, install the official
   GitHub CLI through the normal machine-management process (for example,
   `brew install gh`). Do not commit its credentials or any personal access
   token to this repository.

   ```sh
   gh --version
   ```

2. Authenticate once as a GitHub account that has write access to
   `holdtype/holdtype-swift`. The web authorization opened by this command is
   only the one-time GitHub login for the CLI; release operations themselves
   remain CLI-only.

   ```sh
   gh auth login --hostname github.com --git-protocol ssh --web --scopes repo
   gh auth status
   ```

   `gh auth status` must show the intended active GitHub account and the
   `repo` scope before a release is dispatched. If the CLI is already logged
   in but lacks that scope, refresh the existing login rather than creating a
   token in a shell command:

   ```sh
   gh auth refresh --hostname github.com --scopes repo
   gh auth status
   ```

3. Confirm the current checkout is the pushed `master` release commit and
   dispatch the workflow. Keep every remote operation bounded with the tracked
   timeout helper. Enter the version without the leading `v`; the build must be
   a positive integer. Do not create or push the tag manually.

   ```sh
   git status --short --branch
   scripts/release/with_timeout.py 300 \
     gh workflow run Release \
       --repo holdtype/holdtype-swift \
       --ref master \
       -f version=1.0.7 \
       -f build=8
   ```

4. Find the run ID and monitor it to completion. `gh run watch` can be invoked
   repeatedly with a short timeout; use `gh run view` between attempts to read
   the current state without an unbounded wait.

   ```sh
   scripts/release/with_timeout.py 120 \
     gh run list \
       --repo holdtype/holdtype-swift \
       --workflow Release \
       --limit 1 \
       --json databaseId,url,status,conclusion,headSha,createdAt

   scripts/release/with_timeout.py 60 \
     gh run watch <run-id> \
       --repo holdtype/holdtype-swift \
       --exit-status

   scripts/release/with_timeout.py 60 \
     gh run view <run-id> \
       --repo holdtype/holdtype-swift \
       --json status,conclusion,url,jobs
   ```

   A successful run creates `v<version>`, publishes the notarized DMG and
   metadata, updates the Sparkle appcast and Pages content, and updates the
   configured Homebrew tap. If the run fails, inspect only the failed log
   before changing anything:

   ```sh
   scripts/release/with_timeout.py 120 \
     gh run view <run-id> \
       --repo holdtype/holdtype-swift \
       --log-failed
   ```

If `gh auth status` cannot establish an authenticated account with repository
write access, release dispatch is blocked until that one-time CLI
authentication is completed. Do not switch to Safari, Computer Use, or a
manual tag push as a workaround.

The GitHub Actions release workflow packages, notarizes, and publishes the
locally validated commit. It should:

1. validate `version`, `build`, `tag`, release directory, and download URL
   inputs;
2. import the Developer ID certificate;
3. build and export the Release archive;
4. verify that the exported app embeds the expected Sparkle feed URL and public
   EdDSA key;
5. notarize and staple the app and DMG;
6. generate checksums and verify `release-manifest.json`;
7. fetch the existing Sparkle appcast, treating 404 as first-release absence
   but stopping on server or network failures;
8. generate Sparkle `appcast.xml`;
9. verify signatures, stapled tickets, checksums, the DMG layout, and the DMG
   copy/install path;
10. verify that the appcast and Homebrew cask metadata point at the release DMG
   and SHA-256, and that the appcast build and marketing version match the
   release manifest;
11. prune unexpected assets from an existing GitHub Release so stale
   preview/notary/debug artifacts cannot remain public;
12. publish GitHub Release assets, including the single canonical
   `HoldType.dmg`, while forcing any existing release out of draft/prerelease
   state;
13. deploy the landing page, `appcast.xml`, and all referenced release notes to
   GitHub Pages;
14. verify the GitHub Release is not a draft or prerelease, has the expected
   uploaded non-empty assets, and matches the Pages appcast;
15. prepare and upload the official Homebrew Cask submission bundle using the
   configured `HOMEBREW_MINIMUM_MACOS` value;
16. render, verify, and audit the Homebrew tap cask;
17. open a Homebrew tap pull request.
18. open an official Homebrew Cask bump PR when the official cask has already
   been accepted and official bump automation is enabled.

The workflow wraps GitHub Release publication, tap clone/push, tap pull
request, and official cask bump commands in explicit timeouts. A hung external
service should fail the attempt instead of leaving the release job waiting
indefinitely.

## 8. Verify The Published Release

After the workflow passes, verify:

```sh
scripts/release/with_timeout.py 900 \
  scripts/release/verify_published_release.py \
  --repository holdtype/holdtype-swift \
  --version 1.0.0 \
  --appcast-url https://holdtype.github.io/holdtype-swift/appcast.xml \
  --release-notes-file /path/to/release-notes.md \
  --download-dmg \
  --verify-downloaded-dmg-install
scripts/release/with_timeout.py 60 \
  gh release view v1.0.0 --repo holdtype/holdtype-swift
scripts/release/with_timeout.py 300 \
  gh release download v1.0.0 \
    --repo holdtype/holdtype-swift \
    --pattern 'HoldType.dmg'
shasum -a 256 HoldType.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 HoldType.dmg
scripts/release/verify_dmg_install.sh --dmg HoldType.dmg
```

Open the DMG, drag `HoldType.app` into Applications, and launch it.

For Homebrew, merge the tap pull request, then run:

```sh
scripts/release/verify_homebrew_tap_release.py \
  --repository holdtype/holdtype-swift \
  --tap-repository holdtype/homebrew-tap \
  --expected-homebrew-tap holdtype/tap \
  --version 1.0.0 \
  --sha256 <sha256-of-HoldType.dmg> \
  --minimum-macos ">= :sonoma"
brew tap holdtype/tap
brew trust holdtype/tap
brew install --cask holdtype
brew uninstall --cask holdtype
```

If the workflow uploaded `holdtype-official-homebrew-cask-1.0.0`, download the
artifact, inspect `SUBMISSION.md`, and use
`scripts/release/open_official_homebrew_cask_pr_from_bundle.sh` before opening
the upstream `Homebrew/homebrew-cask` PR. That bundle is evidence for the later
short-form install path:

```sh
brew install --cask holdtype
```

After the upstream PR is merged, run the setup verifier with
`--require-official-homebrew-cask` before using that short command in public
install instructions or enabling official cask bump automation.

For Sparkle, install an older signed build with a test appcast, then verify
that `Check for Updates...` offers the new version, downloads it, installs it,
and relaunches without the normal quit confirmation.
