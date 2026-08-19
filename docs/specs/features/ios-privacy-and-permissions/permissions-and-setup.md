# Historical iOS Permissions And Setup

- Node type: leaf
- Status: Historical
- Read when: reviewing microphone/readiness evidence.
- Do not read when: using it as current handoff setup authority.
- Maximum size: 100 physical lines.

Only app requests/captures microphone; extension never does. Keyboard/Full Access
are user-owned system settings, Full Access ≠ mic, Speech permission unused,
ordinary local typing remains. Launch explains boundaries and never prompts/
records. Mic states allowed/denied/not determined/unavailable; denied leaves
other app/local keyboard usable, uses public Settings without repeated prompt.
Keyboard setup used public route/fallback/practice and never claimed enabled/
default. Fresh evidence meant recently verified; stale meant not currently
verified, never disabled.

iOS17 adapter used AVAudioApplication permission API only from explicit
undetermined Start. Callback revalidated scene/token/consent/key/foreground.
Max wait 120 monotonic seconds; timeout/cancel retired attempt and late result
could affect only later passive status. Denied created no audio/file; granted
without input was unavailable. Purpose string exactly `HoldType uses the
microphone to record speech you choose to transcribe.` Keyboard had no mic API,
AVFAudio, Speech permission, or purpose string.
