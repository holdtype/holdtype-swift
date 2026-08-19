# Dev Vlogs Capture And Camera

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-CAPTURE-1..11`, `DV-CAMERA-1..7`
- Read when: eligible capture, shared audio, source quality, preview, or camera lifecycle is in scope.
- Do not read when: only archive browsing or Build is in scope.
- Maximum size: 100 physical lines.

- One dictation start may start an independent vlog branch. Dictation is
  authoritative; vlog preparation/capture/storage/mux failure never blocks,
  cancels, indefinitely delays, or downgrades usable transcription.
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
