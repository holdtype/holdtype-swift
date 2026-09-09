# Dev Vlogs Capture And Camera

- Node type: leaf
- Status: Active
- Contract revision: `holdtype.macos.dev-vlogs.capture@2`
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-7`
- Clauses: `DV-CAPTURE-1..11`, `DV-CAMERA-1..7`
- Read when: eligible capture, shared audio, source quality, preview, or camera lifecycle is in scope.
- Do not read when: only archive browsing or Build is in scope.
- Maximum size: 100 physical lines.

- One dictation start may start an independent vlog branch. Dictation is
  authoritative; vlog preparation/capture/storage/mux failure never blocks,
  cancels, indefinitely delays, or downgrades usable transcription.
- Camera preparation never gates microphone start. A late camera joins only
  its still-active dictation attempt; finalized output uses the actual overlap.
- Clip uses camera plus the same authoritative dictation microphone speech;
  never open microphone twice. Vlog owns separate state and bounded start.
- Camera capture is visibly indicated. Ready requires playable finalized video
  and audio tracks. Source excludes transcript/context/prompts/keys/responses.
- Camera/macOS negotiate format. HoldType requests no lower resolution/FPS,
  downsample, or additional video encode. Container change/audio mux requires
  proven passthrough; otherwise fail truthfully. Mirror preview only; stored
  orientation remains physical.
- Explicit setup preview lists current cameras. Persist stable device ID/name.
  Disconnect/busy remembers and skips; reconnect recognizes; never substitute.
- Preview/controls/feedback are SwiftUI; only proven system limitation permits
  a narrow rendering adapter. Opening window/Off/Setup never previews/captures.

## Responsiveness delta, revision 2

User-approved start-responsiveness plan, 2026-09-09. Background preparation
removes optional work from the microphone start path. Existing privacy,
durability, export, and capture-authority boundaries remain protected.
Verification covers ordering, cancellation, late completion, and local runtime.
