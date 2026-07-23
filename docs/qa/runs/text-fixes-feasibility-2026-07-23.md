# Text Fixes Feasibility Review

Date: 2026-07-23

Task: HoldType Text Fixes Phase 1

## Decision

- macOS compatible Accessibility text controls: **GO**.
- iOS Voice selected range or complete Draft: **GO**.
- iOS keyboard selected text: **implementation GO, signed-device release
  gate**.
- iOS keyboard no-selection complete field: **NO-GO for the first release**.

The no-selection keyboard result narrows that surface to explicit non-empty
selection. It does not block macOS or iOS Voice.

## Evidence

The review inspected the public platform seams and current HoldType owners
without changing implementation:

- macOS Carbon hotkey registration, focused Accessibility element/value/range,
  parameterized range bounds, and Unicode event posting;
- iOS Voice `UITextView` selection publication, Draft compare-and-swap
  ownership, and app-level Undo;
- `UITextDocumentProxy.selectedText`, document identity, before/after context,
  cursor movement, and insertion;
- current app-private Keychain ownership and App Group dictation boundaries.

No live provider request was made.

## macOS Boundary

`Option+J` can register independently through Carbon. A dedicated target
service can capture the focused non-HoldType Accessibility element, exact
UTF-16 selection or complete value, source, PID, and anchor before the palette
takes focus. Replacement must revalidate that retained target and source,
restore its range, then post one bounded Unicode event.

Runtime qualification remains required for mixed-screen placement, focus
restoration, and host-native one-step Undo in TextEdit, Notes, Safari, Chrome,
and Xcode. Unsupported and secure controls fail closed.

## iOS Voice Boundary

The real Draft `UITextView` can publish its UTF-16 selection. When the Fixes
launcher is invoked during editing, HoldType must capture working text and
selection before ending focus, commit the edit, validate the captured range,
then reserve the existing compare-and-swap transformation transaction.

## Keyboard Boundary

A compatible host's non-empty `selectedText` can be frozen and later replaced
with one `insertText` invocation only while the same controller lifetime,
required document identity, exact selected source, local fingerprint, request,
and expiry still validate.

Public keyboard APIs do not provide a complete-field length, cursor offset,
Select All, or an exact full-field replacement primitive. Before/after context
may be partial or absent. Cursor traversal cannot prove completeness, and
delete-then-insert would mutate source before a provider result is accepted.
The first release therefore requires an explicit selection.

## Remaining Release Gates

- Signed physical iPhone: selected-text continuity through warm and cold
  app-mediated processing, Full Access on/off, extension recreation, expiry,
  host/document changes, and exactly-once replacement.
- macOS runtime: installed `Option+J`, selection/full-field replacement,
  secure-field rejection, stale-target rejection, palette placement, and Undo.
- Simulator: iOS Voice range behavior and keyboard Fixes presentation only.

These gates qualify implemented behavior; they do not authorize a
no-selection keyboard fallback.
