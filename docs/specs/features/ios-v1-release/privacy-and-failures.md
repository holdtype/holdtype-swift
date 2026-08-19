# iOS V1.1 Privacy And Failure Policy

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.privacy@1`
- Read when: provider consent, Full Access, protected data, or failure behavior matters.
- Do not read when: only visual keyboard composition matters.
- Maximum size: 100 physical lines.

- API key stays app-Keychain. Provider consent is current, explicit, app-private,
  and checked before each remote stage. Text Fixes disclosure is version `4`,
  adding invoked selected/qualified-complete-field source and chosen instruction.
  Accepted versions 1–3 require explicit review before another provider request;
  returning cache default off does not lower version.
- Privacy & Permissions shows microphone/OpenAI status and acceptance only when
  review is due; no local-data/History/cache summary, withdrawal action for an
  accepted status, transport/schema/authority/milestone details.
- Consent concisely answers what/why/who/what remains. Exclude ordinary keystrokes
  and unrelated surrounding text. Separate invoked-Fix disclosure covers source.
- Production keyboard has `RequestsOpenAccess=true`; explain Full Access for
  app command/Fixes exchange and that extension neither contacts OpenAI nor
  sends host keystrokes. Without it, voice/Fixes are unavailable; editing,
  Globe, Quick Insert, and safe restricted Latest remain. Extension receives no
  key/provider client.
- Pending audio, canonical History, and full Fix prompts are app-private,
  protected, and backup-excluded per type. Raw audio never enters App Group.
  Expire command, state, immediate-Fix source/result, and Latest eligibility by
  their separate bounded lifetimes.
- Idle session captures/uploads no speech. Capture starts only after Start and
  ends on Finish, Cancel, timeout, interruption, or failure; product state and
  system indicator agree with ownership.
- Logs contain no accepted text, prompt, dictionary, key, provider body, raw
  audio, or host context. External calls have bounded timeouts.

## Failures

Offline/provider failure preserves safely retryable Pending with explicit Retry
or Discard. History failure preserves Latest. Latest failure preserves Pending
until visible recovery or safe local retry. Handoff never fabricates progress.
Unavailable qualified voice degrades to clear instructions, app Voice, Copy,
and Globe while local editing works. Restart never auto-uploads or auto-inserts.
