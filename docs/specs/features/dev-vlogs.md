# Dev Vlogs

- Node type: hybrid
- Contract ID: `holdtype.macos.dev-vlogs`
- Domain ID: `holdtype.macos.dev-vlogs`
- Status: Active
- Stability: Evolving
- Release baseline: explicitly excluded from HoldType `1.0.11`; Debug development only
- Contract revision: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Read when: Dev Vlogs setup, eligibility, capture, archive, Publish, Build, Share, acceptance, or release visibility is in scope.
- Do not read when: ordinary dictation or an unrelated release is in scope.
- Maximum size: 100 physical lines.

## Goal and boundary

An eligible explicit dictation may additionally create one local camera clip
with the same speech, organized for Finder review and explicit day/application
video creation. Dictation remains primary and succeeds independently.

Authorized V1 covers enablement/eligibility, camera, local destination/archive,
Finder-owned review, Build/Export/Share, separate SwiftUI window, and Debug menu.
Protected: dictation/provider/output, durability/History/cache, menu hierarchy,
system Permissions, Keychain/diagnostics/updates, iOS, and released behavior.

## Children

- [Authority and release](dev-vlogs/authority-and-release.md) — active deltas, `1.0.11` exclusion, compatibility, and deferred publication.
- [Enablement and applications](dev-vlogs/enablement-and-applications.md) — setup, Camera permission, app policy, trigger identity, and readiness.
- [Capture and camera](dev-vlogs/capture-and-camera.md) — dictation independence, one audio owner, passthrough, visibility, selection, and reconnection.
- [Destination and archive](dev-vlogs/destination-and-archive.md) — bookmark storage, capacity gates, day/app layout, manifest, and Finder reconciliation.
- [Publish, Build, and Share](dev-vlogs/publish-build-and-share.md) — scope reconstruction, deterministic recipes, passthrough-only output, and delivery boundary.
- [Window and product states](dev-vlogs/window-and-states.md) — Debug menu, SwiftUI sections, presentation states, and lifecycle enums.
- [Failure and durability](dev-vlogs/failure-and-durability.md) — independent failure outcomes, fragments, recovery, logs, and ownership.
- [Acceptance and residuals](dev-vlogs/acceptance-and-residuals.md) — capability gates, phases, required evidence, and nonblocking residuals.
- [Decisions and unknowns](dev-vlogs/decisions-and-unknowns.md) — `DV-D01..D13`, `DV-EU-1..5`, and resolved Build behavior.
- [Research and implementation guidance](dev-vlogs/research-and-guidance.md) — non-normative native-path guidance and source provenance.

## Product invariants

Off by default; explicit eligible dictation only; no hidden/continuous camera;
no silent camera/storage substitution; no source-video downsample/re-encode;
source files separate from History/cache; no transcript beside clips; Finder
owns deletion; Build is non-destructive; V1 stops at local Export/Reveal/Share;
default logs omit content/paths/credentials; all visible UI is SwiftUI.
