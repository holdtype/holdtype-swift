#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/render_homebrew_cask.sh --version 1.0.0 --sha256 SHA \
    --repository owner/repo --output /path/to/Casks/holdtype.rb

Options:
  --version VERSION
  --sha256 SHA256
  --repository OWNER/REPO
  --homepage URL
  --minimum-macos HOMEBREW_VALUE   Example: ">= :tahoe"
  --output PATH
  --help
USAGE
}

VERSION=""
SHA256=""
REPOSITORY="${GITHUB_REPOSITORY:-}"
HOMEPAGE=""
MINIMUM_MACOS=""
OUTPUT_PATH=""
TEMPLATE_PATH="$REPO_ROOT/homebrew/Casks/holdtype.rb.template"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --sha256)
      SHA256="$2"
      shift 2
      ;;
    --repository)
      REPOSITORY="$2"
      shift 2
      ;;
    --homepage)
      HOMEPAGE="$2"
      shift 2
      ;;
    --minimum-macos)
      MINIMUM_MACOS="$2"
      shift 2
      ;;
    --output)
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

[ -n "$VERSION" ] || die "missing --version"
[ -n "$SHA256" ] || die "missing --sha256"
[ -n "$REPOSITORY" ] || die "missing --repository"
[ -n "$OUTPUT_PATH" ] || die "missing --output"
[ -f "$TEMPLATE_PATH" ] || die "template not found: $TEMPLATE_PATH"

validate_release_version "$VERSION"
validate_repository_slug "--repository" "$REPOSITORY"

case "$SHA256" in
  *[!0-9a-fA-F]*)
    die "sha256 must be a 64-character hex digest"
    ;;
esac
[ "${#SHA256}" -eq 64 ] || die "sha256 must be a 64-character hex digest"
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

HOMEPAGE="${HOMEPAGE:-https://github.com/$REPOSITORY}"

if [ -n "$MINIMUM_MACOS" ]; then
  validate_homebrew_macos_requirement "$MINIMUM_MACOS"
  DEPENDS_ON_MACOS="  depends_on macos: \"$MINIMUM_MACOS\""
else
  DEPENDS_ON_MACOS="  # depends_on macos: \">= :tahoe\" # Set when the public minimum macOS version is finalized."
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
VERSION="$VERSION" \
SHA256="$SHA256" \
REPOSITORY="$REPOSITORY" \
HOMEPAGE="$HOMEPAGE" \
DEPENDS_ON_MACOS="$DEPENDS_ON_MACOS" \
python3 - "$TEMPLATE_PATH" "$OUTPUT_PATH" <<'PY'
from __future__ import annotations

import os
import pathlib
import sys

template_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])

text = template_path.read_text()
for key in ("VERSION", "SHA256", "REPOSITORY", "HOMEPAGE", "DEPENDS_ON_MACOS"):
    text = text.replace(f"{{{{{key}}}}}", os.environ[key])

output_path.write_text(text)
PY

verify_args=(
  --cask-path "$OUTPUT_PATH"
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
  --homepage "$HOMEPAGE"
)
if [ -n "$MINIMUM_MACOS" ]; then
  verify_args+=(--minimum-macos "$MINIMUM_MACOS")
fi
"$SCRIPT_DIR/verify_homebrew_cask.py" "${verify_args[@]}" --quiet

log "rendered Homebrew cask: $OUTPUT_PATH"
