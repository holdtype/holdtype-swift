# Dev Vlogs Destination And Archive

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-STORAGE-1..10`, `DV-FOLDER-1..6`, `DV-REVIEW-1..5`
- Read when: destination, capacity, folder identity, manifest, or Finder reconciliation is in scope.
- Do not read when: only camera selection or output rendering is in scope.
- Maximum size: 100 physical lines.

- Default `~/Movies/HoldType Dev Vlogs`; explicit SwiftUI folder picker may
  choose external storage. Persist bookmark identity and validate availability,
  writability, and useful capacity before every capture; never silently fallback.
- Mid-capture loss stops vlog, preserves fragments, and truthfully classifies.
  Active/finalizing assets are protected. No automatic deletion; show day/app
  sizes and require user removal.
- Numeric warning/hard stop require accepted measured negotiated-source byte
  rate/finalization overhead. Hard stop reserves one maximum attempt plus
  overhead. Until safe bound exists, numeric policy stays gated—not guessed.
- Human-readable layout groups local year/day, then sanitized app name + bundle
  ID, clip start time + stable ID, and builds. Manifest stores only stable ID,
  app/time/duration/bytes/camera/health/build membership, never speech/transcript.
- Publish reconstructs disk truth. Finder removal/move marks missing; never
  recreates or claims internal deletion. Open in Finder maps exact selected day
  or app folder. While visible, coalesced observation and explicit Refresh use
  the same reconstruction. No in-app clip list/Delete/exclusion/reorder/editor.
