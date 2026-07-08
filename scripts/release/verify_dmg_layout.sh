#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/verify_dmg_layout.sh --dmg /path/to/HoldType-1.0.0.dmg

Options:
  --dmg PATH
  --app-name NAME       Default: HoldType
  --timeout SECONDS    Default: 300
  --help
USAGE
}

DMG_PATH=""
LAYOUT_APP_NAME="$APP_NAME"
TIMEOUT_SECONDS=300

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dmg)
      DMG_PATH="$2"
      shift 2
      ;;
    --app-name)
      LAYOUT_APP_NAME="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -n "$DMG_PATH" ] || die "missing --dmg"
[ -f "$DMG_PATH" ] || die "DMG not found: $DMG_PATH"

require_command hdiutil

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/holdtype-dmg-layout.XXXXXX")"
ATTACHED=0

cleanup() {
  if [ "$ATTACHED" -eq 1 ]; then
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  fi
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "mounting DMG layout for verification"
run_timed "$TIMEOUT_SECONDS" \
  hdiutil attach \
  -nobrowse \
  -readonly \
  -mountpoint "$MOUNT_DIR" \
  "$DMG_PATH" >/dev/null
ATTACHED=1

APP_PATH="$MOUNT_DIR/$LAYOUT_APP_NAME.app"
APPLICATIONS_LINK="$MOUNT_DIR/Applications"

[ -d "$APP_PATH" ] || die "DMG layout missing $LAYOUT_APP_NAME.app"
[ -e "$APPLICATIONS_LINK" ] || die "DMG layout missing Applications shortcut"
[ -L "$APPLICATIONS_LINK" ] || die "Applications shortcut is not a symlink"

APPLICATIONS_TARGET="$(readlink "$APPLICATIONS_LINK")"
[ "$APPLICATIONS_TARGET" = "/Applications" ] || \
  die "Applications shortcut points to $APPLICATIONS_TARGET, expected /Applications"

log "DMG layout verified: $LAYOUT_APP_NAME.app + Applications shortcut"
