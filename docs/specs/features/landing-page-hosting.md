# Landing Page Hosting

## Goal

Publish the static HoldType product landing page at a stable HTTPS address
without breaking the Sparkle update feed that already uses GitHub Pages.

## Scope

- the static files under `website/`;
- GitHub Pages deployment from this repository;
- the existing Sparkle `appcast.xml` and versioned release-notes pages;
- a later custom-domain move to `holdtype.app`.

## User-visible behavior

- `https://holdtype.github.io/holdtype-swift/` serves the HoldType landing page.
- The page remains usable at a repository subpath and at a future custom-domain
  root without an application build step.
- Download links continue to use the stable GitHub latest-release URL.
- The Homebrew Copy button copies the complete project-tap installation block.
- `appcast.xml` remains available at the stable URL embedded in shipped apps.
- Every release-notes URL referenced by the published appcast remains reachable
  after later website or app releases.

## Invariants

- A Pages deployment is a complete artifact: landing files, appcast, and all
  release notes referenced by that appcast are deployed together.
- A website-only deployment must source the appcast from the latest stable
  GitHub Release rather than regenerate update metadata.
- A release deployment must use the newly generated signed appcast and the
  same release-notes content published in the GitHub Release.
- Website documentation and local QA files are not part of the public artifact.
- Pages deployments are serialized so a website publish cannot race a release
  publish and leave a partial artifact live.
- No custom `CNAME` is published until the domain DNS and GitHub Pages custom
  domain are intentionally configured together.

## Failure policy

- If the latest stable release, its appcast, or any referenced release notes
  cannot be resolved within a bounded timeout, the new deployment fails and the
  previously published Pages site remains in place.
- A landing-page failure must not replace or remove the existing Sparkle feed.
- A release must not report success if its Pages deployment removes the landing
  page or publishes update metadata that differs from the release asset.

## Route / state / data implications

- The initial public root is `https://holdtype.github.io/holdtype-swift/`.
- The existing update-feed route remains
  `https://holdtype.github.io/holdtype-swift/appcast.xml` until a separate
  updater migration changes the shipped `SUFeedURL`.
- Versioned release notes use `HoldType-<version>.md` at the same Pages root.
- A later `holdtype.app` cutover changes hosting and DNS configuration, not the
  static page's relative asset paths.

## Verification mapping

- Workflow checks verify that both website and release publishes construct the
  same complete Pages artifact.
- Artifact tests verify the public-file allowlist, exact appcast copy, and
  reconstruction of every referenced release-notes file.
- Runtime verification checks the deployed root page, current appcast, current
  release notes, Copy interaction, responsive layouts, and browser console.
