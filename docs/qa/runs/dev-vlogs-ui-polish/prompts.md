# Dev Vlogs UI polish — ImageGen reference prompts

Run date: 2026-08-11

All five calls used the real first-pass component crop plus
`components/settings-reference.png`. The references are design evidence only;
no generated pixels ship in HoldType.

## 1. Shell and sidebar

Create a high-fidelity native macOS SwiftUI sidebar matching HoldType Settings.
Keep exactly Overview, Capture, Applications, and Storage, in that order. Use
SF Symbols, lightweight semantic selection, Settings-grade alignment and
spacing, and no additional sections or future placeholders. Ignore the
Computer Use capture indicator and cursor.

Decision: the generated reference confirmed the implemented four-row hierarchy,
icon treatment, and restrained native selection. No correction was required.

## 2. Overview

Preserve the immediate Off/Setup/Ready/degraded state, Enable Dev Vlogs toggle,
three navigable setup rows, compact row status, and one truthful next-action
footer. Improve hierarchy, spacing, semantic status emphasis, and scanability
without adding capture controls or future features.

Decision: the reference confirmed the implemented status-first hierarchy and
setup rows. Its illustrated toggle state contradicted its own Setup status, so
the product kept the truthful runtime state.

## 3. Capture

Preserve Camera Access and Preferred Camera groups, the explicit permission
action, availability/recovery, and the note that opening the page never starts
preview or capture. Improve only spacing, SF Symbol consistency, and action
priority. Add no preview, capture, fallback camera, or passive permission flow.

Decision: the reference matched the implemented grouped hierarchy; no correction
was required.

## 4. Applications

Preserve the recommended Only selected apps policy, the broader explicit
All apps except excluded apps policy, selected/excluded list, Add action, and
human-name-first/bundle-ID-secondary rows. Improve policy clarity, empty-state
compactness, and action priority without inventing policy or placeholder UI.

Decision: the reference validated the recommendation and empty-state hierarchy.
The product retained the native radio-group control because it remained clear,
accessible, and unclipped at the tested supported width.

## 5. Storage

Lead with destination identity and availability; keep the human display name
above the secondary path; preserve truthful recovery, Choose Folder, Use Default
Movies Folder, and the no-silent-fallback note. Do not invent capacity policy,
storage inspection, clips, or future features. Treat the redacted path as
private.

Decision: the reference confirmed the implemented destination-first hierarchy.
The product retained standard Settings-style buttons instead of inventing a
destructive-looking or semantically preferred destination choice.
