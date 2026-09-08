# HoldType static landing page

This folder contains the source for HoldType's statically generated product
landing page. The build uses only Python's standard library and emits one
complete, self-contained site for all ten supported locales.

## Run locally

From the repository root:

```sh
SITE_PREVIEW_DIR="$(mktemp -d)"
python3 website/build_site.py --output-dir "$SITE_PREVIEW_DIR/public"
python3 -m http.server 4173 --directory "$SITE_PREVIEW_DIR/public"
```

Then open <http://localhost:4173/>.

The critical page content, navigation anchors, screenshots, FAQ content, and
download links remain available when JavaScript is disabled. JavaScript is used
only for progressive enhancements: mobile navigation, the labelled illustrative
hero sequence, the Homebrew Copy button, the opt-in video player, and the
full-size screenshot lightbox, the language menu, and root-page locale routing.
Each localized URL contains its complete translated content
in generated HTML, so JavaScript is not required to read or navigate the site.

## Website analytics

The landing page uses the HoldType Google Analytics 4 property and its web
stream for `https://holdtype.app` (Measurement ID `G-055LWPDNZX`). The Google tag in `index.html` is shared by
all ten generated locale pages. It measures website traffic; it does not add
analytics to the macOS or iOS apps. Google signals and advertising
personalization are disabled in the tag configuration.

The tag loads asynchronously and can be blocked without affecting the page.
Google Analytics may store first-party analytics cookies in visitors' browsers.
After publishing, verify the installed tag and page views in the HoldType
property's Realtime report.

## Localization

The public routes are `/` (English and `x-default`), `/es/`, `/de/`, `/fr/`,
`/pt-br/`, `/ja/`, `/zh-hans/`, `/ko/`, `/ru/`, and `/ar/`. Every page includes
a canonical URL plus reciprocal `hreflang` links; `sitemap.xml` lists the same
route set. Arabic is generated with `dir="rtl"`.

The URL is authoritative. On `/` only, JavaScript first uses an explicit saved
choice and otherwise `navigator.languages` to route to a supported non-English
locale. It does not use IP geolocation, browser location permission, cookies,
or a DigitalOcean-specific geo service. Only an explicit selector choice is
stored locally in the browser and it can always be changed from the header.

Edit shared facts and trusted links in `i18n/site.json`, locale metadata in
`i18n/locales.json`, and copy in the corresponding locale catalog. The builder
fails on missing or extra keys, placeholder drift, raw catalog HTML, unsafe
output directories, unexpected locale routes, or a missing or incorrectly sized
social-preview image. Every route uses the same English 1200 × 630 launch
artwork while its Open Graph and X/Twitter alternative text stays localized.

## Hosting

DigitalOcean App Platform serves the product landing page at
<https://holdtype.app/> as a static site with managed HTTPS and CDN delivery.
Its source component is `website/` on `master`, and automatic deployment is
enabled. The canonical App Platform configuration is `.do/app.yaml`.

GitHub Pages remains the canonical host for the Sparkle appcast and versioned
release notes at <https://holdtype.github.io/holdtype-swift/>. The Pages and
release workflows still build one complete Pages artifact so publication cannot
erase update metadata. The release workflow updates Pages when a new app version
ships; the standalone Pages workflow is manual recovery only. Routine website
pushes deploy through DigitalOcean without starting GitHub Pages. Do not point
the shipped update feed at `holdtype.app` as part of a landing-only deployment.

`README.md`, `design-qa.md`, the generator, and the source catalogs are
repository inputs or documentation and are deliberately excluded from public
artifacts. App Platform runs `build_site.py` and publishes only generated HTML,
shared CSS/JavaScript/assets, `sitemap.xml`, and `robots.txt`.

### Publish after every change

After the required checks, commit the task-owned changes on `master` and
immediately push to `origin/master`. Publication is part of the task; a
separate user request is not required. App Platform deploys automatically
after the push. Verify the changed content on `https://holdtype.app/` before
reporting completion. A local preview is not the delivered site.

If a manual rebuild is needed, the existing command deploys and verifies the
site:

```sh
scripts/release/publish_digitalocean.py
```

The command uses the authenticated `doctl` context, discovers the app named
`holdtype` (or accepts `DIGITALOCEAN_APP_ID`), synchronizes the committed
`.do/app.yaml`, deploys its latest source within a bounded timeout, and verifies
all ten locale routes plus `sitemap.xml`. A DigitalOcean API token belongs in
the local `doctl` configuration, never in this repository.

The technical App Platform ingress is always verified first. After DNS cutover,
verify the public domain in the same run as an additional check:

```sh
scripts/release/publish_digitalocean.py --url https://holdtype.app/
```

The first domain cutover must be ordered carefully: verify the DigitalOcean
technical hostname, remove `holdtype.app` from the GitHub Pages custom-domain
setting, confirm the stable `github.io/appcast.xml` no longer redirects, then
attach the domains in App Platform and replace only the old apex and `www` DNS
records at the registrar.

## Files

- `index.html` — semantic page template with localization markers.
- `styles.css` — responsive visual system and reduced-motion behavior.
- `script.js` — language choice/routing plus the mobile menu, hero
  illustration, Copy, opt-in video, and image lightbox interactions.
- `build_site.py` — deterministic static-site generator and catalog validator.
- `build_site_test.py` — focused generator, route, SEO, RTL, and safety tests.
- `i18n/` — locale registry, shared trusted data, and ten copy catalogs.
- `assets/` — local copies of real HoldType product assets.
- `design-qa.md` — final concept-to-browser fidelity report, added after visual QA.

## Full-size screenshot behavior

The Translation, Billing, Quick Fixes, and iPhone gallery screenshots use one
shared in-page modal when JavaScript is available; captions do not duplicate the
action with a text link. The screenshots show the standard pointer cursor and
keep a native link to the original image as their no-JavaScript fallback. The
modal keeps the original image inside the viewport, provides a visible Close
control, closes with Escape or an outside click, locks background scrolling,
and returns focus to the opening screenshot.

## Design direction

The selected direction is **Native macOS Layer**: a true-white canvas, system
typography, thin separators, open section layouts, restrained shadows, and a
single blue-violet product accent. The hero uses a code-native generic editor
scene with real HoldType indicator artwork. It is explicitly labelled as an
illustration rather than a recorded product demo.

### Design-system lock

The implementation uses these fixed decisions from the selected concept:

| Surface | Locked value |
| --- | --- |
| Page background | True white, `#ffffff` |
| Primary text | Graphite, `#17181c` |
| Secondary text | `#5f636c` |
| Small muted text | `#6f737c`, 4.75:1 contrast on white |
| Primary accent | Blue, `#5165e8` |
| Supporting accent | Violet, `#844df2` |
| Dividers | Cool gray, `#e5e7ec` |
| Soft section band | `#f7f8fb` |
| Font stack | `-apple-system`, BlinkMacSystemFont, SF Pro/Segoe UI fallbacks |
| Display line height | `1.08` |
| Body line height | `1.62` |
| Small / medium / large radius | `10px` / `16px` / `24px` |
| Content width | Maximum `1160px`, with 24px desktop and 16px mobile gutters |
| Section rhythm | Responsive `80–132px`; `92px` tablet; `76px` mobile |
| Motion | One finite 3.4-second semantic state sequence and a restrained 3.8-second indicator movement |
| Reduced motion | Static inserted state; CSS animation and smooth scrolling disabled |

Typography scales fluidly from a 52–76px desktop hero to a 41–56px mobile
hero. Section headings use a 36–56px desktop range and a 32–44px mobile range.
Body copy remains at 16px or larger; captions are 12.5px with AA-compliant
foreground color.

The hero's explanatory paragraph uses 19–22px type with a 1.5 line height so
longer localized copy stays subordinate to the headline.

The container model is deliberately open: thin page-width rules, one soft use-
case band, real screenshots in restrained macOS-style frames, and no repeated
card grid. Primary buttons are solid blue; navigation and secondary actions are
text links. Shadows are reserved for the hero editor and real product windows.

### Responsive anatomy

- `1021px+`: split hero, four-step horizontal workflow, five supporting
  product cards, alternating feature rows, and two-column FAQ.
- `861–1020px`: narrower split hero and reduced product-window scale.
- `621–860px`: single-column hero and feature sections, two-step workflow rows,
  compact mobile navigation, and two-column data flow.
- `320–620px`: stacked actions and workflow, single-column data flow and FAQ,
  16px page gutters, and full-width primary CTAs.

The first viewport leads with `Blazing-fast dictation. Built for Mac.` It
addresses people who already use dictation and want a responsive native tool.
The headline names the category, speed, and platform; the lead adds translation
and Quick Fixes in working apps. The support line names the user's OpenAI key
and says that HoldType requires no subscription or sign-up. The approved qualitative
`Blazing-fast` wording is not a comparative benchmark or a promise of
instantaneous cloud processing.
The download qualification and app-price badge distinguish the free app from
separately paid API requests. The hero has one action: the free macOS download.
Source inspection remains in the footer. No unsupported metric, comparative
speed claim, or undocumented competitor claim is permitted.

The code-native editor uses a dry, self-ironic fictional plan to build a tiny
SaaS and reach `$1M ARR`; the interface presents the request as if it were
ordinary. Its caption still identifies the scene as an illustration rather
than a recorded demo and makes no claim that Codex produced the business
result. The toolbar label stays unbranded and on one line, using an ellipsis
rather than wrapping when space is tight. The document title appears only in
the editor body instead of being repeated in the toolbar. The app-price badge
remains visually secondary; it does not advertise a per-dictation API price.

### Page anatomy

1. Sticky brand/navigation header with compact Patreon and GitHub icons plus a
   GitHub Releases CTA.
2. Split hero with the code-native editor illustration and real indicator art.
3. Three-action band: dictation, Quick Fixes for existing text, and translation,
   with shared shortcuts/settings and the most-apps compatibility qualification.
4. Quick Fixes screenshots first, then translation/vocabulary and Last Result
   recovery proof.
5. Compact hold → speak → release → inserted shortcut guide.
6. Five supporting cards: own key, transcription model, optional correction,
   direct OpenAI processing, and local storage.
7. OpenAI billing, the qualified 100-dictation usage example, and exact
   data-boundary explanation.
8. First-person founder story about one native tool across working apps, plus
   the existing microphone photo.
9. GitHub/Homebrew setup and a three-step API-key guide with an opt-in video.
10. Lower-page iPhone source preview with authentic Simulator screens, an
    explicit work-in-progress status, and a source-build path through Xcode.
11. Native FAQ disclosures, final macOS download CTA, and source-available
    footer.

## Asset provenance

The initial page and its visual assets are self-contained under `website/`.
The optional API-key tutorial creates a YouTube privacy-enhanced iframe only
after the user presses Play; the default page makes no YouTube media request.
Original repository assets are not modified.

| Landing asset | Repository source | Treatment |
| --- | --- | --- |
| `app-icon.png` | `docs/readme-assets/app-icon.png` | Copied unchanged |
| `holdtype-social-preview.png` | Approved English launch creative and canonical HoldType icon | Image-generated for the wide composition and exported as an exact 1200 × 630 PNG |
| `indicator-listening.png` | `HoldType/Assets.xcassets/ActivityRecordingIndicatorLight.imageset/ActivityRecordingIndicatorLight@2x.png` | Copied unchanged |
| `indicator-transcribing.png` | `HoldType/Assets.xcassets/ActivityTranscribingIndicatorLight.imageset/ActivityTranscribingIndicatorLight@2x.png` | Copied unchanged |
| `menu-popover.png` | `docs/readme-assets/menu-popover.png` | Copied unchanged |
| `settings-translation.png` | `docs/readme-assets/settings-translation.png` | Proportionally resized to 1400 × 1066 |
| `settings-translation-mobile.png` | `docs/readme-assets/settings-translation.png` | Truthful 1100 × 1000 focus crop of the main settings panel |
| `settings-billing.png` | `docs/readme-assets/settings-billing.png` | Proportionally resized to 1400 × 1066 |
| `settings-billing-mobile.png` | `docs/readme-assets/settings-billing.png` | Truthful 1100 × 1000 focus crop of the main estimate panel |
| `workflow-microphone.jpg` | `docs/readme-assets/workflow-microphone.jpg` | Copied unchanged |
| `quick-fixes-popup.png` | User-provided HoldType capture, `fix-shadow.png` | Copied unchanged; transparent canvas and product-rendered shadow retained |
| `quick-fixes-manage.png` | User-provided HoldType capture, `manage-fixes-shadow.png` | Copied unchanged; transparent canvas and product-rendered shadow retained |
| `holdtype-ios-voice.png` | Fresh `HoldType-iOS` run in the iPhone 16 Pro Simulator on iOS 18.6 | Full 1206 × 2622 Simulator capture, copied unchanged |
| `holdtype-ios-rules.png` | Fresh `HoldType-iOS` run in the iPhone 16 Pro Simulator on iOS 18.6 | Full 1206 × 2622 Simulator capture, copied unchanged |
| `holdtype-ios-keyboard.png` | Real `HoldType Keyboard` shown inside the iPhone 16 Pro Simulator | Exact 1206 × 1132 crop of the keyboard surface; setup and permission instructions are excluded and the keyboard pixels are unchanged |
| `holdtype-ios-settings.png` | Fresh `HoldType-iOS` run in the iPhone 16 Pro Simulator on iOS 18.6 | Full 1206 × 2622 capture of the main Settings screen only |

The public page intentionally does not use the Dictionary screenshot because it
contains personal vocabulary examples. The microphone photo is used only with a
caption that special hardware is not required. The two phone crops contain only
pixels from the corresponding real product screenshots; no controls, values, or
UI states were redrawn or retouched.

## Product-copy boundaries

- HoldType is a native macOS app for macOS 14 or newer.
- The exact API model identifier `gpt-transcribe` appears once in
  subdued secondary copy. Its hyphens and lowercase spelling stay verbatim in
  every locale. It is not used in metadata, headlines, hero lead or support
  copy, proof chips, section headings, founder copy, the final CTA, or the
  footer.
- Model-based correction is optional and off by default. Local typography
  cleanup may still run without another model request.
- It inserts accepted text in **most** Mac apps; it does not claim universal
  compatibility.
- HoldType has no account or recurring fee. OpenAI may require prepaid API
  credit and deducts actual request usage from the user's Platform balance.
- The cost example uses the released default model's `$0.0045/minute` rate,
  checked against OpenAI pricing on 2026-09-08. If 100 dictations total 17
  minutes of speech, transcription costs about `$0.08`, or about `$2.30` when
  repeated daily for 30 days. This is an explicit duration assumption, not a
  fixed per-message price, usage cap, or typical-day claim. Optional correction,
  translation, and Fixes cost extra. Billing estimates locally priced requests
  across those categories and may be incomplete for unknown model rates.
- It uses the user's OpenAI Platform API key, and OpenAI bills API usage
  separately.
- The setup guide never asks for the API key on the website. It links to the
  official OpenAI key page, tells the user to paste the secret only into
  HoldType, and explains that the app stores it locally in macOS Keychain.
- The third-party API-key video is supplementary, attributed, and click-to-load.
  Written steps and official OpenAI links remain sufficient if YouTube is
  unavailable or the tutorial becomes outdated.
- The iPhone app and HoldType Keyboard exist in the repository and can be built
  in Xcode, but they are not yet published in the App Store; the release remains
  explicitly labelled as work in progress.
- Audio goes to OpenAI for transcription. Correction, translation, and Fixes
  send text and instructions when used; nearby cursor context is optional.
- Ordinary completed recordings are not retained by default. Local recovery
  audio may survive relaunch; optional recording-cache retention is separate.
- Last Result recovery requires its save setting to be enabled.
- HoldType has no product account, subscription, telemetry, analytics, backend,
  or cloud sync.
- The project is source-available under FSL 1.1 with an MIT future license; it
  is not described as open source during the FSL period.

## Distribution verification

Distribution configuration updated on 2026-08-05:

- `https://github.com/holdtype/holdtype-swift/releases/latest` resolves to the
  latest public, non-prerelease release.
- Primary Download CTAs use GitHub's stable
  `releases/latest/download/HoldType.dmg` asset link, which advances
  automatically; a secondary `All releases` link opens the full release
  history.
- `holdtype/homebrew-tap` contains `Casks/holdtype.rb` at version `1.0.3`,
  pointing to the same GitHub Release disk image and requiring macOS Sonoma.
- The Homebrew block keeps the explicit project-tap flow (`tap`, `trust`,
  `install`, then `open`) and its Copy button copies all four lines together.
- The page links to OpenAI API pricing alongside its qualified cost example.
  Recheck the example whenever the default model or provider pricing changes.

## Implementation constraints

There is no framework, package manager, external font, form, backend, or API
route. Google Analytics is the landing page's external analytics script; the
site is served through DigitalOcean's CDN. The standard-library build is
bounded by the release tooling. All URLs used for local assets are relative so
the generated artifact can be served at a domain root or under a static-hosting
subpath.
