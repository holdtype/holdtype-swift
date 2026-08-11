# Dev Vlogs P3 Library and Publish QA

Date: 2026-08-11

## Shipping evidence

- `DevVlogsLibraryTests`: archive reconstruction, stable day/app ordering, missing and corrupt media, persistent non-destructive exclusion, exact eligible-clip deletion, replacement and unknown-child fail-closed behavior, sibling/export independence, and active/finalizing/recovering/build ownership rejection.
- `DevVlogsLibrarySafetyTests`: Delete confirmation is bound to the displayed opaque resource identity; review-directory, hard-link, and replacement sentinels survive; reconstruction remains stable across runtime timezone changes; duplicate otherwise-valid clip IDs stay visible but invalid through Library and Publish; Library probe timeout and cancellation remain bounded.
- `DevVlogsMediaBuilderTests`: compatible passthrough creates one playable ordered 1-video/1-audio artifact; incompatible inputs create no output; an existing output is never overwritten.
- `DevVlogsBuildSafetyTests`: source replacement, symlink, and hard-link identity changes fail before media reads; build-parent/workspace/temporary-output replacement fails closed with siblings preserved; source and completed-output probes time out or cancel without false result actions.
- `DevVlogsPublishStoreTests`: Ready/nonexcluded chronological defaults, include/exclude and reorder, recipe persistence before rendering, retry identity, and cancellation preservation.
- Presentation, scene, archive/finalizer, and capture coordinator tests cover real Library/Publish wiring and the shared ownership lease.
- Initial focused shipping pass: 39 tests in 7 suites passed. Repair rerun: all original coverage plus 12 adversarial cases, 51 tests in 9 suites passed.
- Related Dev Vlogs and dictation non-regression: initial 64-test pass; repair-proportional rerun passed 60 tests in 7 suites.
- Swift structure check, unsigned macOS Debug build, and unsigned macOS Release build passed.
- The first post-repair Release attempt exposed a Swift 6.3.3 optimizer crash at the generic main-actor probe gate deinitializer. Explicit lock-backed, nonisolated continuation arbitration preserved the same bounded main-actor media operations; the final unsigned Release build and focused timeout/cancellation tests passed.
- Release artifact scan found no test bundle, Debug/Phase0B artifact, or Phase0B symbol string.
- Source scan found no task-owned logging of transcript text, app content, device identifiers, full paths, media payloads, or secrets.

## Computer Use runtime pass

The required `@oai/sky` Node route was initialized after reading the Computer Use skill and installed Node instructions. A scoped `caffeinate` guard and sanitized `script/build_and_run.sh --verify` launch were used with an exact disposable fixture archive.

Computer Use could inspect and operate ordinary macOS windows, but it could not attach to the windowless HoldType menu-bar process: `get_app_state` returned `timeoutReached` for both the exact run app path and `SystemUIServer`. App-scoped coordinate actions also rejected the global menu-bar target as outside the active window. After those bounded attempts, no launch harness or alternate interaction tooling was added. The Library/Publish click-through scenario, result Play/Reveal/Share opening, and the disposable UI Delete therefore remain for final integrated runtime QA.

The exact run-owned HoldType processes, `caffeinate` guard, disposable fixture archive, and targeting screenshot were removed. No user archive or user-owned app process was touched.

The focused repair packet did not repeat Computer Use or hardware QA. The bounded targeting residual above remains assigned to final integrated QA; no new runtime residual was introduced by the identity and timeout repairs.

## Final safety repair

- Publish rows now keep their opaque reconstructed Library identity separately from an optional canonical clip UUID. Only unique, validated Ready clips expose Include and move actions; a repository-loaded two-clip acceptance case exercises exclusion and movement in both directions without UUID-shaped row fixtures.
- Media source track and full video/audio signature loading is followed by an immediate exact source-and-metadata identity check. A signature-stage replacement case proves the replacement is rejected before export and leaves the source replacement, sibling, and output scope unchanged.
- AVFoundation now writes only into a per-build private `0700` staging directory whose identity and directory descriptor are held for the task. Final promotion uses exclusive `renameatx_np` from that descriptor into a newly opened, no-follow, identity-matched build-directory descriptor, so a concurrent destination cannot be overwritten. A deterministically suspended export case moves and replaces the archive build directory before resume; promotion fails without writing into the replacement target, and exact staging cleanup preserves the source, prior output, sibling, saved recipe, and sentinel.
- Final focused matrix: 54 tests in 9 suites passed. The proportional related matrix passed 47 tests in 7 suites. Structure, unsigned Debug and Release builds, Release isolation, and path-limited diff checks passed.
- Per the final repair packet, Computer Use and hardware QA were not repeated. The previously recorded final-integrated-QA runtime residual is unchanged.

## Terminal micro-repair

- Build staging is now created with `mkdirat` beneath the captured, descriptor-opened `builds` owner rather than in the system temporary directory. The staging directory, owner, and build workspace must share the same device identity before AVFoundation receives the staging URL; cleanup and exclusive promotion remain descriptor-relative and no-follow.
- The filesystem acceptance test injects a mismatched staging-device identity and proves it is rejected, then verifies the real staging and destination device identities match and same-device promotion succeeds. A bounded attempt to use a mounted external volume was abandoned before creating content because that volume blocked on directory creation.
- After every selected source completes its full track and signature probe, the builder now revalidates all source and metadata identities collectively immediately before composition creation. A two-source suspended-signature test replaces already-probed source A while source B is suspended and proves the build fails with no output while replacements, source B, and siblings survive.
- Both exact acceptance tests and all 18 unique tests across the affected Build Safety, Media Builder, and Publish Store suites passed. Structure plus unsigned Debug and Release builds passed; Computer Use and hardware were not run per packet.
