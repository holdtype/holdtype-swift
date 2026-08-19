# Distribution User Trust And Channel Rules

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.distribution-channel@1`
- Clauses: `DISTRIBUTION.CHANNEL`, `DISTRIBUTION.TRUST`, `DISTRIBUTION.FUTURE`
- Read when: official download copy, Store support response, Gatekeeper help, or channel reconsideration is in scope.
- Do not read when: only updater artifact mechanics is in scope.
- Maximum size: 100 physical lines.

- Direct users go to official HoldType download page, which explains Apple
  Developer ID signing and notarization and does not promise Store availability.
- Download builds describe Sparkle updates. Support may explain direct channel
  is required by full system-wide input/insertion workflow.
- Gatekeeper help uses normal macOS confirmation for the signed/notarized app.
  If a clone appears in Store, identify official download source.
- Public privacy/support covers microphone audio, transcript/OpenAI, Keychain,
  AX/Input Monitoring, local History, and diagnostics.
- Reopen Store only after Apple sandbox change and new feasibility/spec, or a
  deliberate weaker edition with its own product behavior contract.
- Final download/support/privacy URLs and whether Homebrew ships initially remain open.
