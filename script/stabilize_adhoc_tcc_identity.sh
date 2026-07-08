#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:?app bundle path is required}"
BUNDLE_ID="${2:-app.holdtype.HoldType}"
REQUIREMENTS_FILE="${3:-}"

if [[ -z "$REQUIREMENTS_FILE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    REQUIREMENTS_FILE="$ROOT_DIR/Config/HoldTypeAdHocDesignatedRequirement.txt"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
    printf 'HoldType TCC identity stabilization skipped: app bundle not found: %s\n' "$APP_BUNDLE" >&2
    exit 0
fi

signing_details="$(/usr/bin/codesign -dvvv "$APP_BUNDLE" 2>&1 || true)"
if [[ "$signing_details" != *"Signature=adhoc"* && "$signing_details" != *"TeamIdentifier=not set"* ]]; then
    exit 0
fi

requirement="$(/usr/bin/codesign -d -r- "$APP_BUNDLE" 2>&1 || true)"
if [[ "$requirement" != *"designated => cdhash"* ]]; then
    exit 0
fi

if [[ -d "$APP_BUNDLE/Contents/MacOS" ]]; then
    while IFS= read -r -d '' nested_code; do
        /usr/bin/codesign --force --sign - "$nested_code"
    done < <(
        /usr/bin/find "$APP_BUNDLE/Contents/MacOS" \
            -maxdepth 1 \
            -type f \
            \( -name '*.debug.dylib' -o -name '__preview.dylib' \) \
            -print0
    )
fi

/usr/bin/codesign \
    --force \
    --sign - \
    --preserve-metadata=entitlements,flags \
    --requirements "$REQUIREMENTS_FILE" \
    "$APP_BUNDLE"
