# Dev Vlogs Research And Implementation Guidance

- Node type: leaf
- Status: Historical support
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Read when: planning a selected capture/storage implementation after the Active clause path is pinned.
- Do not read when: deciding product intent or accepting a capability by analogy.
- Maximum size: 100 physical lines.

This is non-normative evidence. The lowest-risk explored path keeps the current
authoritative audio recorder, adds camera-only capture, records monotonic bounds,
leases completed audio to a finalizer, muxes by native passthrough, validates
tracks, then releases the lease. Bookmark-backed destination is revalidated
before every capture; temporary fragmented media is validated before atomic publication.

AVFoundation device/session/export, fragment interval, frontmost app, mount and
capacity APIs, SwiftUI file selection, and macOS Share were primary platform
sources. Tella, Screen Studio, OBS, Rewind discussion, and Descript supported
workflow risks but do not define HoldType behavior. FFmpeg and future social
upload documentation remain development/reference evidence, not V1 dependencies.

Research supports short dictation-defined clips, explicit preview/device state,
independent vlog failure, external-drive recovery, visible storage, and local
export-first delivery. It does not authorize continuous capture, cloud projects,
a full editor, dense broadcasting controls, FFmpeg shipping, or remote publication.

Implementation guidance and the linked project plan cannot override Active
clauses, acceptance residuals, SwiftUI boundary, or release exclusion.
