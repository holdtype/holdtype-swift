# HoldType Landing Page Working Plan

Status: accepted positioning for the HoldType landing page and product introduction

Positioning decision: 2026-09-08, approved in the direct product-positioning chat

## Audience And Product Position

Address people who already use voice input. They are choosing a daily tool
based on responsiveness, native Mac interaction, consistency across apps, and
control over processing. Do not spend the first screen teaching them that
speaking can be faster than typing.

HoldType is one native Mac tool for dictation, translation, and Quick Fixes.
The user's shortcuts, settings, and text commands remain familiar when they
move between AI tools, editors, email, and notes.

Primary job:

> Give me one responsive voice and text tool across the apps I work in, with
> my own OpenAI key and control over the processing steps.

Quick Fixes is part of the core product definition. HoldType remains useful
when the text already exists: select it, run a built-in or saved command, and
replace it in place in supported fields.

The product's character is a focused native Mac utility: ready at a shortcut,
compact, responsive, and under the user's control. Lead with that experience.
Direct API billing and the lack of a HoldType subscription support the choice.

The previous competitor-clone positioning and the proposal to lead with
speaking a complete thought are retired. Competitor names belong in sourced
comparison material, not the headline, founder story, or product definition.

## Approved First Screen

Headline:

> Blazing-fast dictation. Built for Mac.

Lead:

> Translation and Quick Fixes, right where you work.

Support:

> Your OpenAI key. No HoldType subscription.

Primary action:

> Download free for macOS

Qualification:

> Free app · OpenAI API usage billed separately · macOS 14+

Russian headline:

> Молниеносная диктовка. Создан для Mac.

Use natural equivalents in all ten supported languages. Translate `Built for
Mac` as made or designed for Mac, not as a literal fragment about being
`native`. The Russian `Нативно на Mac` wording is retired as an unnatural
technical calque. Adapt sentence structure to each language. Keep the platform,
API-key requirement, separate API billing, and compatibility boundaries clear.
The headline must name dictation, speed, and the Mac platform. The previous
`One tool. Across your Mac.` / `Один инструмент. Для всего Mac.` slogan is
retired: it was too broad and did not identify what the tool does. Cross-app
use and Quick Fixes support the headline; they do not imply a general-purpose
tool for every Mac task or compatibility with every text field.

## What Backs The Position

- **One familiar interaction:** a global shortcut invokes dictation in the
  working app; translation has its own shortcut. Do not imply that one key
  performs every action or that Quick Fixes commands are necessarily spoken.
- **Native Mac utility:** a Swift app in the menu bar, with a floating activity
  indicator and native controls. Do not infer a measured latency advantage
  from its implementation language alone.
- **Voice and existing text:** dictation, translation, and Quick Fixes form one
  tool. Custom Fixes let users save recurring text edits.
- **Direct processing:** the user's OpenAI key connects the app directly to
  OpenAI. HoldType adds no speech-processing server, account, or subscription.
- **Optional extra correction:** the separate model-based correction step is
  off by default. Local typography cleanup may still run.

Independence means a common tool across working apps and a direct OpenAI
account relationship. It does not mean provider-neutral operation, offline
transcription, or freedom from OpenAI availability and API billing.

The transcription model identifier is secondary technical copy. Keep it once
in the processing details, driven by `website/i18n/site.json`, rather than in
headlines or repeated promotional claims.

## Page Order

1. Hero: blazing-fast dictation and native Mac identity, followed by translation
   and Quick Fixes, the key and billing qualification, and one download action.
2. Three-action band: dictation in the current app, Quick Fixes for existing
   text, and translation on its own shortcut. State the most-apps boundary.
3. Quick Fixes screenshots, followed by translation/vocabulary and Last Result
   recovery. Demonstrate the available actions before detailing architecture.
4. Compact shortcut guide: hold, speak, release, inserted. This teaches the
   gesture without making a case against typing.
5. Processing and control: own key, model, optional correction, direct requests,
   local settings and storage.
6. Cost and data boundary, including the qualified usage example.
7. Founder story: one tool across working apps, built in Swift, with direct API
   billing and optional extra correction.
8. Download, permissions and API-key setup; Homebrew remains secondary.
9. Explicitly labelled iPhone work-in-progress preview.
10. FAQ, final Mac download action, and source-available footer.

## Demonstration Direction

The existing hero is a labelled illustration, not recorded performance proof.
Retain its label and authentic indicator artwork. Existing Quick Fixes and
translation screenshots provide product evidence alongside it.

A future recorded demonstration should show the same tool across applications:
invoke dictation in one app, switch apps, invoke it again, then apply Quick
Fixes to existing text. Show the real interaction and processing delay. Do not
simulate a faster response or represent an illustration as a runtime recording.
A new recording is a separate asset-production task.

## Market Context

Research checked on 2026-09-08. These are competitors' own descriptions, not
independent benchmark results or evidence of HoldType superiority.

| Product | Relevant current presentation | Implication |
| --- | --- | --- |
| [Aqua](https://aquavoice.com/info/faq) | Publishes startup and post-speech latency claims | Responsiveness is a buying criterion; comparisons need actual measurements. |
| [Typeless](https://www.typeless.com/) | Dictation, translation, and actions on existing text | Voice and text editing belong together; the combination alone is not an exclusivity claim. |
| [Spokenly](https://spokenly.app/pricing) | Own API keys without a product subscription | BYOK and no subscription are useful terms, not unique inventions. |
| [Superwhisper](https://superwhisper.com/docs/security/sensitive-data) | Own API keys in Pro and enterprise workflows | Explain the direct account relationship concretely. |
| [Wispr Flow](https://wisprflow.ai/) | Voice replacing typing, polished output, and cross-app use | HoldType's audience already understands dictation; focus on choosing the daily tool. |

## Shared Copy And Product Boundaries

- Keep the landing, GitHub introduction, and future campaign copy aligned with
  this position. Existing launch artwork already uses the approved native Mac
  and blazing-fast direction; its literal alt text must match the actual image.
- `Blazing-fast` is approved qualitative wording for dictation, including the
  hero and metadata. It is not permission to publish `fastest`, speed
  multipliers, zero-latency claims, or guaranteed instant translation/Fixes.
- Do not describe competitors' models as outdated or their apps as slower
  without current attributable evidence and a suitable comparison.
- The app works in most Mac apps; text replacement depends on the target field.
- HoldType is free. OpenAI API usage is billed separately through the user's
  Platform account. ChatGPT subscriptions do not include that API usage.
- Keep the qualified cost example and rate in shared site data; do not
  describe it as a fixed price per dictation or typical daily usage. Correction,
  translation, and Quick Fixes are additional requests.
- Audio goes to OpenAI. Correction, translation, and Fixes send text and
  instructions when used. Nearby-cursor context is optional.
- The key stays in macOS Keychain. Settings, dictionary, and history are local.
  Ordinary recording retention is off by default; recovery audio may remain
  after restarting the app. Last Result saving must be enabled for recovery.
- The app has no product analytics or cloud sync. The website's analytics are
  separate and must not be described as app telemetry.
- The website never asks visitors to submit an API key. The written setup path
  remains sufficient; the supplementary attributed video loads only on Play.
- The iPhone app and keyboard remain explicitly labelled work in progress,
  available to build from source and not yet published in the App Store.
- Source is available under FSL 1.1 with an MIT future license. Do not call the
  project open source during the FSL period.

## Acceptance For Positioning Changes

Keep localized copy, English template fallbacks, metadata, the product
introduction, and this brief consistent. Preserve download destinations,
privacy disclosures, setup instructions, and locale routes. Generate the
static site to validate catalogs and token parity, and check the scoped diff.
Commit the task-owned changes on master and immediately push to origin/master
without waiting for a separate publication request. Wait for the automatic
deployment and verify the changed content on https://holdtype.app/ before
reporting completion. Local previews and local commits are intermediate work.
No app implementation, model migration, or app runtime QA is part of this
marketing change.
