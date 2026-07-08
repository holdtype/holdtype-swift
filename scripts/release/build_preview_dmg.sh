#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/build_preview_dmg.sh --version 1.0.0 --build 100

Creates a local, non-notarized preview DMG under dist/preview/. This validates
the app build, update-setting plist keys, DMG layout, ZIP, checksum, and
manifest path without requiring Developer ID certificates, notarization
credentials, Sparkle keys, or GitHub secrets.

The output is not a public release artifact.

Options:
  --version VERSION          Marketing version without leading v
  --build BUILD             CFBundleVersion / preview build number
  --preview-dir PATH        Output directory, default dist/preview/vVERSION
  --help
USAGE
}

VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
PREVIEW_ROOT="${PREVIEW_ROOT:-$REPO_ROOT/dist/preview}"
PREVIEW_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --preview-dir)
      PREVIEW_DIR="$2"
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

[ -n "$VERSION" ] || die "missing --version"
[ -n "$BUILD_NUMBER" ] || die "missing --build"
validate_release_version "$VERSION"
validate_build_number "$BUILD_NUMBER"

RELEASE_ROOT="$PREVIEW_ROOT"
PREVIEW_TAG="$(release_tag_for_version "$VERSION")"
PREVIEW_DIR="${PREVIEW_DIR:-$PREVIEW_ROOT/$PREVIEW_TAG}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$PREVIEW_DIR/DerivedData}"
PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/Release"
BUILT_APP_PATH="$PRODUCTS_DIR/$APP_NAME.app"
EXPORT_PATH="$PREVIEW_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
APP_ZIP_PATH="$PREVIEW_DIR/$APP_NAME-$VERSION.zip"
DMG_PATH="$PREVIEW_DIR/$APP_NAME-$VERSION.dmg"
APP_ZIP_FILE="$(basename "$APP_ZIP_PATH")"
DMG_FILE="$(basename "$DMG_PATH")"
STAGING_DIR="$PREVIEW_DIR/dmg-staging"
MANIFEST_PATH="$PREVIEW_DIR/preview-manifest.json"
SHA256SUMS_PATH="$PREVIEW_DIR/SHA256SUMS.txt"
SHA256SUMS_FILE="$(basename "$SHA256SUMS_PATH")"

XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-2400}"
DISK_IMAGE_TIMEOUT_SECONDS="${DISK_IMAGE_TIMEOUT_SECONDS:-600}"

require_command xcodebuild
require_command hdiutil
require_command ditto
require_command shasum

safe_rm_generated_dir "$PREVIEW_DIR"
mkdir -p "$EXPORT_PATH"

log "building local preview app $APP_NAME $VERSION ($BUILD_NUMBER)"
run_timed "$XCODEBUILD_TIMEOUT_SECONDS" \
  xcodebuild \
  -project "$REPO_ROOT/$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  HOLDTYPE_UPDATE_FEED_URL="${HOLDTYPE_UPDATE_FEED_URL:-}" \
  HOLDTYPE_UPDATE_PUBLIC_ED_KEY="${HOLDTYPE_UPDATE_PUBLIC_ED_KEY:-}" \
  build

[ -d "$BUILT_APP_PATH" ] || die "built app not found at $BUILT_APP_PATH"

log "copying preview app"
cp -R "$BUILT_APP_PATH" "$EXPORT_PATH/"

log "verifying preview update setting keys"
"$SCRIPT_DIR/verify_app_update_settings.py" \
  --app "$APP_PATH" \
  --allow-unconfigured

log "verifying preview app signature"
run_timed 300 codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "creating preview zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP_PATH"

log "creating preview DMG"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
run_timed "$DISK_IMAGE_TIMEOUT_SECONDS" \
  hdiutil create \
  -volname "$APP_NAME $VERSION Preview" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

log "verifying preview DMG layout"
"$SCRIPT_DIR/verify_dmg_layout.sh" --dmg "$DMG_PATH"

log "verifying preview DMG install copy"
"$SCRIPT_DIR/verify_dmg_install.sh" --dmg "$DMG_PATH" --skip-codesign

log "writing preview checksums"
(
  cd "$PREVIEW_DIR"
  shasum -a 256 "$DMG_FILE" "$APP_ZIP_FILE" > "$SHA256SUMS_FILE"
)

DMG_SHA256="$(sha256_for_file "$DMG_PATH")"
ZIP_SHA256="$(sha256_for_file "$APP_ZIP_PATH")"

cat > "$MANIFEST_PATH" <<EOF
{
  "app": "$APP_NAME",
  "kind": "local-preview",
  "version": "$VERSION",
  "build": "$BUILD_NUMBER",
  "tag": "$PREVIEW_TAG",
  "notarized": false,
  "public_release": false,
  "dmg": {
    "path": "$DMG_FILE",
    "sha256": "$DMG_SHA256"
  },
  "zip": {
    "path": "$APP_ZIP_FILE",
    "sha256": "$ZIP_SHA256"
  }
}
EOF

"$SCRIPT_DIR/verify_release_manifest.py" \
  --manifest "$MANIFEST_PATH" \
  --artifact-root "$PREVIEW_DIR" \
  --expect-kind local-preview \
  --expect-public-release false \
  --expect-notarized false \
  --require-relative-artifact-paths

log "preview artifacts ready: $PREVIEW_DIR"
