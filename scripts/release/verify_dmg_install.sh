#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/verify_dmg_install.sh --dmg /path/to/HoldType-1.0.0.dmg

Options:
  --dmg PATH
  --app-name NAME       Default: HoldType
  --install-dir PATH    Default: temporary directory removed on exit.
  --skip-codesign       Copy-smoke only. Intended for unsigned preview/test DMGs.
  --keep-install-dir    Keep the temporary install directory for inspection.
  --timeout SECONDS     Default: 300
  --help
USAGE
}

DMG_PATH=""
INSTALL_APP_NAME="$APP_NAME"
INSTALL_DIR=""
SKIP_CODESIGN=0
KEEP_INSTALL_DIR=0
TIMEOUT_SECONDS=300

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dmg)
      DMG_PATH="$2"
      shift 2
      ;;
    --app-name)
      INSTALL_APP_NAME="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --skip-codesign)
      SKIP_CODESIGN=1
      shift
      ;;
    --keep-install-dir)
      KEEP_INSTALL_DIR=1
      shift
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
require_command ditto
if [ "$SKIP_CODESIGN" -eq 0 ]; then
  require_command codesign
fi

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/holdtype-dmg-install-mount.XXXXXX")"
CREATED_INSTALL_DIR=0
if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/holdtype-dmg-install-target.XXXXXX")"
  CREATED_INSTALL_DIR=1
else
  mkdir -p "$INSTALL_DIR"
fi
ATTACHED=0

cleanup() {
  if [ "$ATTACHED" -eq 1 ]; then
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  fi
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
  if [ "$CREATED_INSTALL_DIR" -eq 1 ] && [ "$KEEP_INSTALL_DIR" -eq 0 ]; then
    rm -rf "$INSTALL_DIR"
  fi
}
trap cleanup EXIT

log "mounting DMG for install verification"
run_timed "$TIMEOUT_SECONDS" \
  hdiutil attach \
  -nobrowse \
  -readonly \
  -mountpoint "$MOUNT_DIR" \
  "$DMG_PATH" >/dev/null
ATTACHED=1

SOURCE_APP_PATH="$MOUNT_DIR/$INSTALL_APP_NAME.app"
TARGET_APP_PATH="$INSTALL_DIR/$INSTALL_APP_NAME.app"

[ -d "$SOURCE_APP_PATH" ] || die "DMG install source missing $INSTALL_APP_NAME.app"
if [ -e "$TARGET_APP_PATH" ]; then
  die "install target already exists: $TARGET_APP_PATH"
fi

log "copying app from DMG to install target"
run_timed "$TIMEOUT_SECONDS" ditto "$SOURCE_APP_PATH" "$TARGET_APP_PATH"

[ -d "$TARGET_APP_PATH" ] || die "copied app not found at $TARGET_APP_PATH"
[ -f "$TARGET_APP_PATH/Contents/Info.plist" ] || die "copied app is missing Contents/Info.plist"

if [ "$SKIP_CODESIGN" -eq 0 ]; then
  log "verifying copied app signature"
  run_timed 300 codesign --verify --deep --strict --verbose=2 "$TARGET_APP_PATH"
fi

log "DMG install copy verified: $TARGET_APP_PATH"
