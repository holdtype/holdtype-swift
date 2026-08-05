#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/generate_appcast.sh --release-dir dist/release/v1.0.0 \
    --download-url-prefix https://github.com/owner/repo/releases/download/v1.0.0/ \
    --release-notes-url-prefix https://owner.github.io/repo/release-notes/v1.0.0/ \
    --ed-key-file /path/to/sparkle_ed25519_key

Options:
  --release-dir PATH
  --download-url-prefix URL
  --release-notes-url-prefix URL
  --ed-key-file PATH
  --release-notes-file PATH
  --existing-appcast PATH
  --output-path PATH        Default: RELEASE_DIR/appcast.xml
  --help
USAGE
}

RELEASE_DIR=""
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-}"
RELEASE_NOTES_URL_PREFIX="${RELEASE_NOTES_URL_PREFIX:-}"
ED_KEY_FILE="${SPARKLE_EDDSA_PRIVATE_KEY_FILE:-}"
RELEASE_NOTES_FILE=""
EXISTING_APPCAST=""
OUTPUT_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release-dir)
      RELEASE_DIR="$2"
      shift 2
      ;;
    --download-url-prefix)
      DOWNLOAD_URL_PREFIX="$2"
      shift 2
      ;;
    --release-notes-url-prefix)
      RELEASE_NOTES_URL_PREFIX="$2"
      shift 2
      ;;
    --ed-key-file)
      ED_KEY_FILE="$2"
      shift 2
      ;;
    --release-notes-file)
      RELEASE_NOTES_FILE="$2"
      shift 2
      ;;
    --existing-appcast)
      EXISTING_APPCAST="$2"
      shift 2
      ;;
    --output-path)
      OUTPUT_PATH="$2"
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

[ -n "$RELEASE_DIR" ] || die "missing --release-dir"
[ -n "$DOWNLOAD_URL_PREFIX" ] || die "missing --download-url-prefix"
[ -z "$RELEASE_NOTES_FILE" ] || [ -n "$RELEASE_NOTES_URL_PREFIX" ] || \
  die "missing --release-notes-url-prefix"
[ -n "$ED_KEY_FILE" ] || die "missing --ed-key-file"
[ -f "$ED_KEY_FILE" ] || die "EdDSA key file not found: $ED_KEY_FILE"
require_command python3

OUTPUT_PATH="${OUTPUT_PATH:-$RELEASE_DIR/appcast.xml}"
APPCAST_DIR="$RELEASE_DIR/appcast-archives"
MANIFEST_PATH="$RELEASE_DIR/release-manifest.json"

[ -f "$MANIFEST_PATH" ] || die "release-manifest.json not found in $RELEASE_DIR"
if ! DMG_FILE="$(
  python3 - "$MANIFEST_PATH" <<'PY'
import json
import sys

manifest_path = sys.argv[1]
with open(manifest_path, encoding="utf-8") as handle:
    data = json.load(handle)
dmg = data.get("dmg")
if not isinstance(dmg, dict):
    raise SystemExit("manifest dmg object is missing")
path = dmg.get("path")
if not isinstance(path, str) or not path:
    raise SystemExit("manifest dmg.path is missing")
print(path)
PY
)"; then
  die "could not read DMG path from release-manifest.json"
fi
case "$DMG_FILE" in
  */* | "")
    die "manifest dmg.path must be an artifact filename: $DMG_FILE"
    ;;
esac
DMG_PATH="$RELEASE_DIR/$DMG_FILE"
[ -f "$DMG_PATH" ] || die "manifest DMG not found: $DMG_PATH"
if ! RELEASE_VERSION="$(
  python3 - "$MANIFEST_PATH" <<'PY'
import json
import sys

manifest_path = sys.argv[1]
with open(manifest_path, encoding="utf-8") as handle:
    data = json.load(handle)
version = data.get("version")
if not isinstance(version, str) or not version:
    raise SystemExit("manifest version is missing")
print(version)
PY
)"; then
  die "could not read version from release-manifest.json"
fi
validate_release_version "$RELEASE_VERSION"
if [ -n "$RELEASE_NOTES_FILE" ]; then
  python3 - "$RELEASE_NOTES_URL_PREFIX" "$RELEASE_VERSION" <<'PY'
import sys
import urllib.parse

prefix = sys.argv[1]
version = sys.argv[2]
parsed = urllib.parse.urlparse(prefix)
expected_suffix = f"/release-notes/v{version}/"
if (
    parsed.scheme != "https"
    or not parsed.netloc
    or parsed.query
    or parsed.fragment
    or not parsed.path.endswith(expected_suffix)
):
    raise SystemExit(
        "release notes URL prefix must be an HTTPS URL ending in "
        f"{expected_suffix}: {prefix!r}"
    )
PY
fi

safe_rm_generated_dir "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DMG_PATH" "$APPCAST_DIR/"

if [ -n "$RELEASE_NOTES_FILE" ]; then
  [ -f "$RELEASE_NOTES_FILE" ] || die "release notes file not found: $RELEASE_NOTES_FILE"
  cp "$RELEASE_NOTES_FILE" "$APPCAST_DIR/${DMG_FILE%.dmg}.md"
fi

if [ -n "$EXISTING_APPCAST" ]; then
  [ -f "$EXISTING_APPCAST" ] || die "existing appcast not found: $EXISTING_APPCAST"
  cp "$EXISTING_APPCAST" "$APPCAST_DIR/appcast.xml"
fi

GENERATE_APPCAST="$(find_generate_appcast)"

GENERATE_APPCAST_ARGS=(
  --ed-key-file "$ED_KEY_FILE"
  --download-url-prefix "$DOWNLOAD_URL_PREFIX"
)
if [ -n "$RELEASE_NOTES_FILE" ]; then
  GENERATE_APPCAST_ARGS+=(--release-notes-url-prefix "$RELEASE_NOTES_URL_PREFIX")
fi

log "generating Sparkle appcast"
run_timed "${APPCAST_TIMEOUT_SECONDS:-600}" \
  "$GENERATE_APPCAST" \
  "${GENERATE_APPCAST_ARGS[@]}" \
  -o "$APPCAST_DIR/appcast.xml" \
  "$APPCAST_DIR"

cp "$APPCAST_DIR/appcast.xml" "$OUTPUT_PATH"
log "appcast ready: $OUTPUT_PATH"
