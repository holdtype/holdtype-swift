# HoldType Landing Page Working Plan

Status: working brief for a future `holdtype.app` landing page

Research snapshot: 2026-07-09

## Product Position

HoldType is a focused native macOS voice-input tool for people who write long
AI prompts, messages, reviews, documentation, and notes. Its primary audience
is comfortable using an OpenAI Platform API key and values a native workflow,
direct provider billing, and no additional product account or subscription.

Primary job:

> When a thought is longer than I want to type, let me say it without leaving
> the app where I am working, then put the accepted text at the cursor.

Secondary job:

> Let me speak in the language where the thought comes naturally and insert the
> result in the language my work requires.

Recommended positioning line:

> Speak the whole thought. HoldType puts it where you're working.

Supporting line:

> Native macOS voice input for long AI prompts, messages, docs, and notes.
> Bring your own OpenAI API key; no HoldType account or subscription.

## Role Of Each Surface

The README and landing page should share the same positioning, but they do not
have the same job:

- **GitHub README:** convert an already interested visitor, establish technical
  trust, provide the direct download, and support source inspection.
- **Product landing page:** demonstrate the result to a first-time visitor,
  explain BYOK and privacy without repository context, and answer purchase or
  download objections.
- **Launch and ongoing content:** create attention outside either page through
  a reusable demo, founder story, measured examples, release notes, and factual
  comparison content.

A polished README can improve conversion and trust, but it cannot create
distribution on its own. The first demo asset should therefore work in the
README, on the landing page, and in external launch posts.

## What The Market Currently Emphasizes

This is a positioning study, not a feature checklist.

| Product | Strongest presentation pattern | Lesson for HoldType |
| --- | --- | --- |
| [Wispr Flow](https://wisprflow.ai/) | A quantified speed promise, immediate before/after demonstration, repeated download CTA, and extensive social proof | Show the result before explaining settings. Do not copy speed multipliers without HoldType-specific measurement. |
| [OpenWhispr](https://openwhispr.com/) | Privacy and user control directly after the hero, plus a concise GitHub README with direct downloads | Explain the data boundary early. Keep HoldType focused instead of matching OpenWhispr's meetings, notes, agents, and local-model breadth. |
| [Superwhisper](https://superwhisper.com/) | A short “speak → polished text” hero, visible demo, concrete coding workflows, and clear local/cloud data-flow documentation | Use a real end-to-end demo and show the apps where HoldType is useful. Avoid turning model choice into the headline. |
| [VoiceInk](https://tryvoiceink.com/) | Native Mac and privacy positioning, concrete use cases, founder presence, pricing clarity, and public source as trust | Combine founder credibility with product proof. Avoid accuracy and speed claims without a reproducible method. |
| [MacWhisper](https://www.macwhisper.com/) | Use-case-led product breadth, UI proof, reviews, and a clear one-time purchase story | Borrow use-case clarity, not the all-in-one transcription-studio scope. |

## Recommended Page Order

### 1. Hero

Goal: explain the outcome, platform, and commercial boundary within five
seconds.

- Headline: `Speak the whole thought. HoldType puts it where you're working.`
- Supporting copy: native macOS voice input, own OpenAI key, most Mac apps.
- Primary CTA: `Download HoldType for macOS`.
- Secondary CTA: `Watch the 20-second demo`.
- Qualification: `Free app · OpenAI API usage billed separately · macOS 14+`.

### 2. End-To-End Demo

Show the actual product result, not a Settings window:

1. The cursor is visible in Codex, Claude, ChatGPT, Mail, or Notes.
2. Right Command is held and the floating indicator appears.
3. A natural spoken paragraph is recorded.
4. The accepted text appears at the cursor after release.

The ideal asset is a silent 10–20 second video with a compact caption. A short
GIF can be the fallback for GitHub.

### 3. Three Reasons To Choose HoldType

Keep this layer limited to three decisions:

1. Native, system-wide Mac input that stays around the active app.
2. The user's OpenAI key and direct OpenAI billing, with no HoldType account or
   subscription.
3. Practical output control: translation, vocabulary hints, minimal correction,
   and Last Result recovery.

### 4. Work It Fits

Use real before/after examples rather than profession tiles:

- a detailed prompt for a coding agent;
- a review or explanation that would otherwise be shortened;
- a message or note dictated without opening another editor;
- Russian speech inserted as an English reply;
- a project name corrected with Dictionary spelling context.

### 5. Cost And Data Boundary

Explain the decision in one place:

- HoldType is free; OpenAI bills API usage directly;
- ChatGPT subscriptions and OpenAI Platform API billing are separate;
- the local Billing view currently estimates successful audio transcriptions,
  not correction or translation requests;
- audio goes to OpenAI for transcription;
- optional correction and translation are separate text requests;
- the key stays in Keychain;
- completed audio is not retained by default, while a recoverable failed
  attempt may keep bounded session-only audio for Retry;
- HoldType has no account, product backend, telemetry, analytics, or cloud sync.

A simple data-flow visual can make this easier to scan:

`Microphone → HoldType → OpenAI transcription → optional text step → active app`

### 6. Founder Story

Keep the story specific and short:

- typing speed was not the problem; long thoughts were being shortened;
- existing tools were useful, but the desired combination was narrower:
  native Swift, BYOK, direct billing, no extra account;
- HoldType is built and tested through the same Codex-heavy voice workflow;
- the desk microphone photo belongs here, with a note that special hardware is
  not required.

### 7. Trust And Proof

Use evidence that can be checked:

- signed and notarized current release;
- current macOS requirement;
- public source and release history;
- short privacy explanation;
- measured examples with the model, recording length, date, and method;
- real user quotes only after permission and attribution.

### 8. Download, Setup, And FAQ

Repeat the primary download CTA, then provide the shortest setup path. Homebrew
is secondary to the disk image.

FAQ should answer:

- Why is an OpenAI API key required?
- Is ChatGPT Plus enough?
- What does dictation usually cost?
- What data is sent to OpenAI?
- Is audio stored?
- Which Mac apps work?
- Which languages are supported?
- Why are microphone, Accessibility, and Input Monitoring permissions needed?
- Is HoldType open source or source-available?

## Assets And Evidence Still Needed

Priority 0:

- 10–20 second end-to-end demo in a real target app;
- hero frame that shows the cursor, floating indicator, and inserted text;
- a short first-run guide for permissions and the OpenAI key;
- a working public website before linking it from the README;
- a documented cost example that states what the estimate includes.

Priority 1:

- anonymized voice-to-text before/after examples;
- a Dictionary vocabulary example;
- screenshots for Transcript History, Permissions, and Updates;
- a list of tested apps and known insertion limitations;
- measured latency for a few recording lengths;
- early user quotes or usage stories.

Priority 2:

- a factual comparison page with dated sources;
- a privacy/data-flow graphic;
- an Open Graph image and small brand kit;
- a decision on English-only versus localized landing pages.

## Claims Policy

Do not publish `3x faster`, `5x faster`, `99% accurate`, `perfect`, `private`,
or `works in every app` without a documented HoldType-specific method and the
necessary qualifications.

Prefer claims that are already observable:

- native macOS app;
- own OpenAI API key;
- no HoldType account or subscription;
- audio sent to OpenAI for transcription;
- optional separate correction and translation requests;
- local Keychain, settings, recovery, and recording-cache controls;
- source available for inspection.

## First Measurement Pass

The landing page can be validated without adding telemetry to the app. Start
with GitHub release-download counts, direct feedback, and a small set of
permissioned user interviews. Measure the page itself only if a separate,
privacy-conscious website analytics decision is made.
