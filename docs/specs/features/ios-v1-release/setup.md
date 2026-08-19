# iOS V1.1 Setup

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.setup@1`
- Read when: governing setup, permissions, Full Access, or practice behavior.
- Do not read when: setup is complete and only runtime behavior matters.
- Maximum size: 100 physical lines.

- Explain adding/switching to HoldType Keyboard and enabling Allow Full Access
  for keyboard-controlled dictation.
- Provider setup owns key entry and current OpenAI-processing consent.
- The app requests microphone permission only on first recording or explicit review.
- Put one keyboard-switch/insertion practice field in a compact Voice toolbar
  sheet, not the primary Voice canvas.
- No required `Start Keyboard Session`: valid cold microphone request creates
  the bounded session and starts capture.
- State that the app records even under keyboard control. If unavailable, the
  same microphone opens HoldType without keyboard navigation instructions.
- History and Settings open in the app; normal typing stays on the system
  keyboard and Globe switches keyboards.
- Full Access recovery opens the dedicated setup destination with public Open
  System Settings and practice field. System steps live there; report Full
  Access as not currently verified, never claim direct toggle visibility.
- Punctuation, Space, Delete, Return, Globe, and already-available restricted
  Latest need no provider setup, microphone, network, or Full Access.
  Keyboard-controlled dictation needs Full Access and a valid app-owned session.
