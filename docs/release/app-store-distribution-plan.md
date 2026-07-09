# Mac App Store Distribution Plan

Research date: 2026-07-09.

This document plans a Mac App Store distribution track for HoldType. It does
not replace the existing direct-download release track. The current repository
already has a Developer ID, notarized DMG, Sparkle appcast, GitHub Release, and
Homebrew Cask pipeline; the App Store track should run beside it until App
Store compatibility is proven.

## Primary References

- Apple App Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect build upload guide:
  https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Apple App Store Connect app record guide:
  https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- Apple App Store Connect review submission guide:
  https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/
- Apple TestFlight overview:
  https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- Apple certificates overview:
  https://developer.apple.com/help/account/certificates/certificates-overview/
- Apple App Sandbox upload information:
  https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information
- Apple app privacy guide:
  https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple screenshot requirements:
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple export compliance guide:
  https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- fastlane App Store Connect API guide:
  https://docs.fastlane.tools/app-store-connect-api/
- fastlane `upload_to_app_store` guide:
  https://docs.fastlane.tools/actions/upload_to_app_store/
- fastlane `upload_to_testflight` guide:
  https://docs.fastlane.tools/actions/upload_to_testflight/

## Current Repository State

The macOS target is currently shaped for direct distribution:

- Bundle identifier: `app.holdtype.HoldType`.
- Version settings: `MARKETING_VERSION = 1.0`,
  `CURRENT_PROJECT_VERSION = 1`.
- Current public minimum under Xcode settings:
  `MACOSX_DEPLOYMENT_TARGET = 26.5`.
- Release build setting: `ENABLE_HARDENED_RUNTIME = YES`.
- Release build setting: `ENABLE_APP_SANDBOX = NO`.
- App icon catalog: `AppIcon`.
- `HoldType/Info.plist` includes:
  - `LSUIElement = true` for menu-bar behavior.
  - `NSMicrophoneUsageDescription`.
  - `NSInputMonitoringUsageDescription`.
  - Sparkle keys `SUFeedURL` and `SUPublicEDKey`.
- Sparkle is resolved through SwiftPM and direct distribution docs already
  define Sparkle as a non-App-Store updater.
- `.github/workflows/release.yml` builds on `v*` tags, imports a Developer ID
  certificate, notarizes the app and DMG, publishes GitHub Release assets,
  generates a Sparkle appcast, and prepares Homebrew metadata.
- `Config/ExportOptions.DeveloperID.plist` uses Xcode export method
  `developer-id`.

The product spec currently blocks a straight App Store submission:
`docs/specs/features/privacy-and-permissions.md` states that the macOS MVP app
target must not use App Sandbox while active-app insertion, Paste Last Result,
or nearby text context depend on Accessibility-gated control of other apps.

## App Store Constraints That Matter Here

Apple's Mac App Store rules make three constraints non-negotiable for this
project:

1. Mac App Store apps must be appropriately sandboxed.
2. Mac App Store apps must be submitted with Xcode-provided packaging
   technologies, as self-contained app bundles, without third-party installers.
3. Mac App Store apps must use the Mac App Store for updates; external update
   mechanisms are not allowed.

That means the first App Store milestone is not "upload the current DMG". It is
"prove that HoldType can run correctly as a sandboxed App Store build, with
App Store-managed updates."

## Recommended Distribution Model

Use two explicit distribution flavors:

| Flavor | Signing | Packaging | Updates | Purpose |
| --- | --- | --- | --- | --- |
| Direct | Developer ID Application | Notarized DMG and ZIP | Sparkle | GitHub download and Homebrew |
| App Store | Apple Distribution or Mac App Distribution, plus installer export as needed | App Store Connect package/export | Mac App Store | Store trust, TestFlight, easier install |

Do not remove the direct channel. It remains the fallback if sandboxed active
text insertion or nearby context cannot pass App Review without unacceptable
product compromises.

## Key Product Decisions

### Bundle Identifier

Default recommendation: keep `app.holdtype.HoldType` for the App Store build
unless the sandbox spike proves we need a separate Store-only identity.

Reasons to keep it:

- one product identity;
- easier App Store page naming;
- simpler user support language;
- direct and Store builds are clearly the same app.

Reasons to split it, for example `app.holdtype.HoldType.store`:

- direct and Store builds need to coexist during migration testing;
- sandbox container migration becomes too risky;
- App Review requires behavior that should not affect the direct channel;
- Store-specific entitlements or settings become too divergent.

Decide this before creating the App Store Connect app record. Changing the
bundle ID later creates avoidable release and migration work.

### App Store Product Behavior

Before implementation, create or update a spec under `docs/specs/` for the App
Store distribution flavor. It should settle:

- whether App Store builds offer every direct-build feature;
- what happens if sandboxing blocks active-app text insertion;
- whether the Store build has a reduced fallback mode, for example
  copy-to-clipboard with manual paste, if automated insertion cannot be
  approved;
- how Settings describes updates in Store builds;
- whether Sparkle UI is hidden or replaced with "Updates are managed by the
  App Store";
- how privacy copy describes audio, transcript text, nearby text context, and
  OpenAI requests.

### Pricing

If HoldType is free, the Apple Developer Program agreement is enough for free
App Store distribution. If HoldType is paid or offers paid feature unlocks,
the Account Holder must accept the Paid Apps Agreement and complete banking
and tax setup. If in-app unlocks are added later, they need App Store
in-app purchase design and review.

## Required Repository Artifacts

### Product And Release Docs

- `docs/specs/features/app-store-distribution.md`
  - new product contract for Store-specific behavior, sandbox expectations,
    update behavior, review/demo behavior, and privacy promises.
- Update `docs/specs/features/privacy-and-permissions.md`
  - replace the current "must not use App Sandbox" absolute with a split
    direct-vs-Store contract only after the sandbox spike proves behavior.
- Update `docs/specs/features/software-updates.md`
  - direct builds keep Sparkle;
  - Store builds must not use Sparkle as an update channel.
- `docs/release/app-store-release-runbook.md`
  - exact first-release steps after implementation is done.

### Xcode And Signing Files

- `HoldType/AppStore.entitlements`
  - start with the smallest plausible sandbox profile:
    - `com.apple.security.app-sandbox = true`;
    - `com.apple.security.network.client = true`;
    - `com.apple.security.device.audio-input = true`.
  - add temporary exception entitlements only if a bounded sandbox test proves
    they are required. Each exception needs a usage explanation for App Store
    Connect and likely a Feedback Assistant bug ID if it works around a missing
    sandbox feature.
- Optional `HoldType/Direct.entitlements`
  - only if separating direct and Store signing makes the project clearer.
- Build setting wiring for distribution flavor:
  - direct Release keeps current Developer ID behavior;
  - App Store Release enables sandbox and points at the Store entitlement file;
  - Store builds omit or disable Sparkle feed/public-key configuration.
- `Config/ExportOptions.AppStoreConnect.plist`
  - Xcode 26.6 reports `app-store-connect` as the current export method.
    The old `app-store` method is deprecated.
  - include `signingStyle`, `stripSwiftSymbols`, `uploadSymbols`, and either
    `destination = export` for local package validation or
    `destination = upload` for direct upload.

### Release Automation Scripts

Keep the current shell/Python release style unless fastlane is explicitly
adopted.

- `scripts/release/build_app_store.sh`
  - archive the App Store flavor with bounded `xcodebuild` timeouts;
  - pass `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `DEVELOPMENT_TEAM`,
    and Store-specific build settings;
  - export with `Config/ExportOptions.AppStoreConnect.plist`;
  - produce a local App Store package/export artifact and manifest.
- `scripts/release/verify_app_store_export.py`
  - verify bundle ID;
  - verify `ENABLE_APP_SANDBOX` entitlements in the exported app;
  - verify network/audio sandbox entitlements;
  - verify Sparkle update feed is absent or Store-disabled;
  - verify `LSUIElement`, microphone usage text, and input monitoring usage
    text remain present;
  - verify version/build numbers match release inputs.
- `scripts/release/upload_app_store_build.sh`
  - upload using Xcode export destination `upload`, Transporter, or fastlane;
  - use App Store Connect API key auth;
  - wrap upload in an explicit timeout;
  - never print private key contents.
- `scripts/release/verify_app_store_connect_setup.py`
  - read-only verification of required environment variables and local tooling;
  - optionally call App Store Connect API to confirm the app record exists,
    bundle ID matches, and the numeric app Apple ID is configured.

### CI Workflows

- `.github/workflows/app-store.yml`
  - manual `workflow_dispatch` first;
  - environment protection, for example `app-store`;
  - `build` job: test, archive, export, verify artifact;
  - `upload-testflight` job: upload to App Store Connect/TestFlight;
  - optional `submit-review` job: disabled until at least one manual App
    Review submission succeeds.

Do not trigger this workflow on every `v*` tag initially. The existing tag
workflow already publishes direct-channel artifacts. Start App Store upload as
an explicit manual release action so App Store failures cannot block or corrupt
the direct release.

### Optional fastlane Layer

fastlane can be added once the binary upload path is understood:

- `Gemfile` with pinned `fastlane`.
- `fastlane/Appfile` for app identifier, team ID, and Apple ID.
- `fastlane/Fastfile` lanes:
  - `beta`: upload to TestFlight;
  - `metadata`: upload metadata and screenshots without binary;
  - `submit`: submit latest build for review after an operator approval gate.
- `fastlane/metadata/en-US/*`
  - app name, subtitle, description, keywords, support URL, marketing URL,
    privacy URL, release notes.
- `fastlane/screenshots/en-US/*`
  - generated, review-safe Mac screenshots.

Use App Store Connect API key auth, not an Apple ID password session, for CI.
fastlane currently supports API key auth for `pilot`, `deliver`, `sigh`,
`cert`, `match`, `precheck`, and related actions. Team keys are recommended
for provisioning-related automation.

## App Store Connect Setup Checklist

Operator-owned setup in App Store Connect:

1. Confirm the latest agreements are accepted.
2. Decide whether the app is free, paid download, or has IAP.
3. If paid or IAP, accept the Paid Apps Agreement and complete tax/banking.
4. Register or confirm the Bundle ID.
5. Create a macOS app record:
   - app name: `HoldType`, if available;
   - bundle ID: probably `app.holdtype.HoldType`;
   - SKU: stable internal value, for example `holdtype-macos`;
   - primary language: likely English.
6. Confirm the numeric App Store Connect app Apple ID.
7. Create a Team App Store Connect API key.
8. Configure TestFlight internal tester group.
9. Prepare privacy policy URL and support URL.
10. Prepare app category, age rating, pricing, availability, and export
    compliance answers.

## Access Needed

Minimum access for setup and automation:

- Apple Developer Account Holder or Admin for agreements, certificates,
  identifiers, and API key setup.
- App Store Connect App Manager for app record, metadata, TestFlight, and
  review submission.
- Developer role can upload builds, but cannot complete all product/review
  setup alone.
- Marketing role can help with metadata and screenshots.
- GitHub repository admin access to add secrets, variables, and protected
  environments.

Recommended GitHub secrets and variables:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_BUNDLE_ID`
- `APP_STORE_APPLE_ID`
- optional `APP_STORE_PROVIDER_SHORT_NAME`, if Transporter requires a provider
  selection

Only add certificate `.p12` secrets if automatic or cloud signing cannot cover
the Store export. If manual Store signing becomes necessary, add separate
Store-specific secrets rather than reusing Developer ID material:

- `APP_STORE_DISTRIBUTION_CERTIFICATE_BASE64`
- `APP_STORE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APP_STORE_INSTALLER_CERTIFICATE_BASE64`
- `APP_STORE_INSTALLER_CERTIFICATE_PASSWORD`
- provisioning profile material if Xcode cannot fetch it through
  `-allowProvisioningUpdates`.

Do not commit certificates, API keys, provisioning profiles, or private key
files.

## Metadata And Product Assets

Required before first review:

- App name: `HoldType`, subject to availability.
- Subtitle: short, non-hype description of menu-bar dictation.
- Category: likely Productivity or Utilities; choose once the product
  positioning is final.
- Description: must accurately explain:
  - menu-bar dictation;
  - OpenAI transcription;
  - user-provided OpenAI API key;
  - microphone and Accessibility/Input Monitoring permissions;
  - text insertion behavior.
- Keywords: no competitor names, no trademark stuffing.
- Support URL: public page with contact path and permission troubleshooting.
- Privacy Policy URL: public policy covering microphone audio, transcript text,
  nearby text context if enabled, OpenAI API use, local Keychain storage, local
  history, diagnostics, and the absence or presence of analytics.
- Review notes:
  - exact steps to grant microphone, Accessibility, and Input Monitoring;
  - why these permissions are core to the app;
  - whether reviewer needs an OpenAI API key;
  - if needed, provide a temporary operator-created OpenAI review key or a
    built-in demo mode. Do not store that key in the repository.
- Screenshots:
  - minimum one and maximum ten Mac screenshots;
  - Apple currently accepts Mac screenshots in 16:10 at 1280x800, 1440x900,
    2560x1600, or 2880x1800;
  - use actual app UI with fictional transcript text and no real API keys;
  - recommended set: menu popover, first-run setup, OpenAI key setup,
    transcription settings, permission settings, text correction/translation,
    transcript history, and recording indicator.
- App preview video:
  - optional;
  - if added for macOS, it must be landscape and processed by App Store
    Connect.
- App icon:
  - verify the `AppIcon` asset includes the required marketing/icon sizes and
    appears correctly in the archive.
- Accessibility Nutrition Labels:
  - evaluate VoiceOver, Voice Control, Larger Text, Dark Interface,
    Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion,
    Captions, and Audio Descriptions honestly before submission.

## Privacy And Compliance Work

HoldType should prepare a privacy worksheet before entering App Store Connect
privacy answers. The final answers are product/legal decisions, not just
engineering defaults.

Likely areas to disclose or explicitly rule out:

- microphone audio sent to OpenAI for transcription;
- transcript text sent to OpenAI for correction or translation when enabled;
- nearby text context sent to OpenAI when contextual prompting is enabled;
- OpenAI API key stored locally in Keychain;
- local transcript history and local usage estimate history;
- diagnostic bundle contents;
- crash reports, if any external crash reporter is ever added;
- analytics/telemetry, currently expected to be absent unless the product
  changes.

Export compliance must be answered because the app uses network transport and
system encryption. If App Store Connect determines no documentation is
required, add the recommended Info.plist export compliance key so the same
questions do not block every submission.

## Sandbox Feasibility Spike

This is the first implementation milestone.

Goal: prove whether the current product can work as a sandboxed Mac App Store
app without unacceptable behavior loss.

Steps:

1. Create a temporary Store entitlement file with app sandbox, network client,
   and audio input.
2. Build a local Store-flavored Release archive without uploading.
3. Inspect entitlements with:

   ```sh
   codesign -dvvv --entitlements :- /path/to/HoldType.app
   ```

4. Run the app in a clean local QA account or with reset TCC state.
5. Verify microphone recording with bounded timeouts and fake transcription
   where possible.
6. Verify global hotkey registration.
7. Verify Input Monitoring request behavior.
8. Verify Accessibility request behavior.
9. Verify active-app text insertion into TextEdit and one browser text field.
10. Verify Paste Last Result.
11. Verify nearby text context, if enabled.
12. Verify Keychain read/write under sandbox.
13. Verify transcript history storage path and migration behavior.
14. Verify quitting and launch-at-login consent behavior.

Possible outcomes:

- Full pass: proceed with Store build flavor.
- Pass with temporary exceptions: document each exception, add App Store
  usage information, and expect higher review risk.
- Text insertion/context fail: decide whether Store build ships a reduced
  clipboard/manual-paste mode or whether App Store distribution is deferred.
- Permission registration fail: do not proceed to App Review until the product
  permission flow is redesigned and specified.

## Build And Upload Flow

First local export command shape:

```sh
xcodebuild archive \
  -project HoldType.xcodeproj \
  -scheme HoldType \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath dist/app-store/HoldType.xcarchive \
  MARKETING_VERSION=1.0.0 \
  CURRENT_PROJECT_VERSION=100 \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  HOLDTYPE_DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  HOLDTYPE_CODE_SIGN_STYLE=Automatic \
  HOLDTYPE_UPDATE_FEED_URL= \
  HOLDTYPE_UPDATE_PUBLIC_ED_KEY=
```

First export command shape:

```sh
xcodebuild -exportArchive \
  -archivePath dist/app-store/HoldType.xcarchive \
  -exportPath dist/app-store/export \
  -exportOptionsPlist Config/ExportOptions.AppStoreConnect.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$APP_STORE_CONNECT_API_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
```

For upload automation, either:

- set `destination = upload` in the export options and let Xcode upload during
  export; or
- export locally, verify the package, then upload with Transporter or
  fastlane `pilot`.

The second option is safer for the first implementation because it gives us a
stable local artifact to inspect before Apple-side upload.

## TestFlight Flow

1. Upload the first Store build to App Store Connect.
2. Wait for build processing.
3. Add internal testers first.
4. Run internal TestFlight on a clean Mac:
   - install from TestFlight;
   - complete setup;
   - perform dictation with a review-safe OpenAI key or fake/demo path;
   - confirm no Sparkle update prompt exists;
   - confirm App Store/TestFlight update path is the only update story.
5. Add external testers only after internal install and permission flows pass.
6. Expect the first external TestFlight build to need beta review.

## Review Submission Flow

Manual first submission:

1. Upload the build.
2. Complete metadata, screenshots, privacy, age rating, pricing, availability,
   and export compliance.
3. Add specific App Review notes for permissions and OpenAI key/demo access.
4. Submit for review.
5. Capture rejection messages and responses in `docs/release/` or QA notes.
6. Only after one successful manual review, consider enabling fastlane or API
   review submission.

Automated later submission:

- use fastlane `deliver` or App Store Connect API review-submission endpoints;
- require a protected GitHub environment approval before submit;
- keep "auto-submit to review" disabled for ordinary tag releases until the
  Store track has several clean releases.

## Release Versioning

Use the same marketing version as the direct release when both channels ship
the same product, for example `1.0.0`.

Use a monotonically increasing `CURRENT_PROJECT_VERSION` for App Store Connect.
For repeat uploads under the same marketing version, only the build number
changes.

Do not rely on the existing `v*` tag workflow for Store upload at first.
Recommended sequence:

1. Direct channel ships from `v1.0.0`.
2. App Store workflow is manually dispatched from the same commit with
   `version=1.0.0` and a Store build number.
3. Store upload creates the TestFlight/App Review candidate.

## Definition Of Done For First App Store Release

- App Store distribution spec exists and matches implementation.
- Sandboxed local Store build passes the permission and text insertion QA
  matrix, or documented Store-specific fallback behavior is implemented.
- Store build has no external updater behavior.
- Store export artifact is verified locally.
- App Store Connect app record is complete.
- Privacy policy, support URL, screenshots, age rating, export compliance, and
  review notes are complete.
- Internal TestFlight install passes on a clean Mac.
- External TestFlight or App Review acceptance is achieved.
- App Store release can be repeated from a documented command or GitHub
  workflow with bounded external timeouts.

## Open Questions

- Is `HoldType` available as an App Store app name?
- Do we keep `app.holdtype.HoldType` for both direct and Store builds?
- Is macOS `26.5` the intended first public minimum, or should the target move
  lower before public Store review?
- Can active text insertion and nearby context pass in App Sandbox?
- Will the first Store release be free, paid upfront, or paired with future IAP?
- What public support and privacy policy URLs should App Store Connect use?
- Should App Review receive a temporary OpenAI API key, or should we implement
  a review/demo mode?
- Do we want fastlane as a new Ruby dependency, or keep Store automation in the
  repo's existing shell/Python style?

## Immediate Next Steps

1. Confirm bundle ID and pricing direction.
2. Create the Store distribution spec.
3. Run the sandbox feasibility spike locally.
4. If the spike passes, add Store entitlements and export options.
5. Add local Store build/export verification scripts.
6. Create the App Store Connect app record and API key.
7. Upload the first internal TestFlight build.
