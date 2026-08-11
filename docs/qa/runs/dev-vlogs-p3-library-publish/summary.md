# Dev Vlogs P3 Library and Publish QA

Date: 2026-08-11

## Shipping evidence

- `DevVlogsLibraryTests`: archive reconstruction, stable day/app ordering, missing and corrupt media, persistent non-destructive exclusion, exact eligible-clip deletion, replacement and unknown-child fail-closed behavior, sibling/export independence, and active/finalizing/recovering/build ownership rejection.
- `DevVlogsMediaBuilderTests`: compatible passthrough creates one playable ordered 1-video/1-audio artifact; incompatible inputs create no output; an existing output is never overwritten.
- `DevVlogsPublishStoreTests`: Ready/nonexcluded chronological defaults, include/exclude and reorder, recipe persistence before rendering, retry identity, and cancellation preservation.
- Presentation, scene, archive/finalizer, and capture coordinator tests cover real Library/Publish wiring and the shared ownership lease.
- Focused shipping pass: 39 tests in 7 suites passed.
- Related Dev Vlogs and dictation non-regression pass: 64 tests in 7 suites passed.
- Swift structure check, unsigned macOS Debug build, and unsigned macOS Release build passed.
- Release artifact scan found no test bundle, Debug/Phase0B artifact, or Phase0B symbol string.
- Source scan found no task-owned logging of transcript text, app content, device identifiers, full paths, media payloads, or secrets.

## Computer Use runtime pass

The required `@oai/sky` Node route was initialized after reading the Computer Use skill and installed Node instructions. A scoped `caffeinate` guard and sanitized `script/build_and_run.sh --verify` launch were used with an exact disposable fixture archive.

Computer Use could inspect and operate ordinary macOS windows, but it could not attach to the windowless HoldType menu-bar process: `get_app_state` returned `timeoutReached` for both the exact run app path and `SystemUIServer`. App-scoped coordinate actions also rejected the global menu-bar target as outside the active window. After those bounded attempts, no launch harness or alternate interaction tooling was added. The Library/Publish click-through scenario, result Play/Reveal/Share opening, and the disposable UI Delete therefore remain for final integrated runtime QA.

The exact run-owned HoldType processes, `caffeinate` guard, disposable fixture archive, and targeting screenshot were removed. No user archive or user-owned app process was touched.
