# iOS V1.1 Scope And Non-goals

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.scope@1`
- Read when: deciding whether a capability belongs to V1.1.
- Do not read when: only detailed behavior of an included capability matters.
- Maximum size: 100 physical lines.

## Included

- iPhone Setup, Voice, Dictation Rules, compact History, Usage, and Settings.
- Foreground app recording/OpenAI plus one bounded app-owned keyboard session.
- Existing optional correction/translation; one Pending; one Latest; one
  app-private composed Voice Draft; app-private Fixes and immediate selection flow.
- Up to 20 successful text-only History entries; optional app-private Recording
  Cache, off by default, for explicitly enabled local playback.
- Production iPhone command keyboard with actionable Start, Finish, and Cancel;
  microphone-owned cold handoff and no extension Settings/History/launch button.
- Automatic insertion only by the same active, visible keyboard controller for
  its live request/host; explicit `Latest` after returning; one bounded,
  time-limited History-latest projection.
- Existing informational Usage immediately before Settings; no keyboard copy.
- Bottom-of-Settings Development section with local Diagnostics & Support,
  bounded redacted app/keyboard logs, explicit copy/share, and local crash evidence.
- One distribution-signed TestFlight candidate plus metadata, privacy, and
  review artifacts needed for an App Store-submission decision.
- Existing iPad containing-app adaptation is best-effort compatibility UI,
  neither marketed nor release-qualified.

The command surface has no typing locale. It inserts accepted Unicode in any
supported transcription language; chrome localization adds no alphabetic layout.

## Excluded

- Multiple failed-attempt History, more than one unfinished Pending, retry-audio
  queues, generations, outboxes, tombstones, receipts, or transaction protocols.
- Automatic provider retry after relaunch or insertion into unverified/changed host.
- Microphone, key, prompts, OpenAI code, or raw audio in the extension.
- QWERTY/number/symbol decks, Shift/Caps, predictions, autocorrection, locale
  dictionaries, Apple trade dress, or Apple emoji assets.
- General background Quick Session, automatic app return, policy bypass,
  indefinite background recording, idle-speech retention, or silent keepalive.
- Configurable session duration, cloud sync, accounts, analytics, profiles,
  modes, Live Activity, billing, production iPad floating/Stage Manager, or
  hardware-keyboard shortcuts.
- Buying enrollment/dependencies or guaranteeing App Review. Submission stays
  an explicit release-owner action after recorded gates pass.
