#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/prepare_official_homebrew_cask.sh \
    --homebrew-cask-dir "$(brew --repository homebrew/cask)" \
    --version 1.0.0 --sha256 SHA --repository owner/repo \
    --minimum-macos ">= :tahoe"

Options:
  --homebrew-cask-dir PATH       Local Homebrew/homebrew-cask checkout or fork.
  --version VERSION
  --sha256 SHA256
  --repository OWNER/REPO
  --homepage URL
  --minimum-macos HOMEBREW_VALUE Required. Example: ">= :tahoe"
  --audit                        Run brew audit --new --cask holdtype.
  --brew PATH                    Defaults to BREW_BIN or brew.
  --audit-timeout SECONDS        Defaults to 600.
  --help

The script renders the official Homebrew Cask candidate at
Casks/h/holdtype.rb. It does not fork, commit, push, or open the PR.
USAGE
}

HOMEBREW_CASK_DIR=""
VERSION=""
SHA256=""
REPOSITORY="${GITHUB_REPOSITORY:-}"
HOMEPAGE=""
MINIMUM_MACOS="${HOMEBREW_MINIMUM_MACOS:-}"
AUDIT=0
BREW_BIN="${BREW_BIN:-brew}"
AUDIT_TIMEOUT=600
CASK_TOKEN="holdtype"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --homebrew-cask-dir)
      HOMEBREW_CASK_DIR="$2"
      shift 2
      ;;
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
    --audit)
      AUDIT=1
      shift
      ;;
    --brew)
      BREW_BIN="$2"
      shift 2
      ;;
    --audit-timeout)
      AUDIT_TIMEOUT="$2"
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

[ -n "$HOMEBREW_CASK_DIR" ] || die "missing --homebrew-cask-dir"
[ -d "$HOMEBREW_CASK_DIR" ] || die "Homebrew Cask checkout not found: $HOMEBREW_CASK_DIR"
[ -n "$VERSION" ] || die "missing --version"
[ -n "$SHA256" ] || die "missing --sha256"
[ -n "$REPOSITORY" ] || die "missing --repository"
[ -n "$MINIMUM_MACOS" ] || die "missing --minimum-macos or HOMEBREW_MINIMUM_MACOS"

validate_release_version "$VERSION"
validate_repository_slug "--repository" "$REPOSITORY"
validate_homebrew_macos_requirement "$MINIMUM_MACOS"

case "$SHA256" in
  *[!0-9a-fA-F]*)
    die "sha256 must be a 64-character hex digest"
    ;;
esac
[ "${#SHA256}" -eq 64 ] || die "sha256 must be a 64-character hex digest"
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

CASK_PATH="$HOMEBREW_CASK_DIR/Casks/${CASK_TOKEN:0:1}/$CASK_TOKEN.rb"
render_args=(
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
  --output "$CASK_PATH"
)

if [ -n "$HOMEPAGE" ]; then
  render_args+=(--homepage "$HOMEPAGE")
fi
render_args+=(--minimum-macos "$MINIMUM_MACOS")

"$SCRIPT_DIR/render_homebrew_cask.sh" "${render_args[@]}"

verify_args=(
  --cask-path "$CASK_PATH"
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
  --official-layout
)
if [ -n "$HOMEPAGE" ]; then
  verify_args+=(--homepage "$HOMEPAGE")
fi
verify_args+=(--minimum-macos "$MINIMUM_MACOS" --require-minimum-macos)
"$SCRIPT_DIR/verify_homebrew_cask.py" "${verify_args[@]}" --quiet

if [ "$AUDIT" -eq 1 ]; then
  require_command "$BREW_BIN"
  log "auditing official Homebrew Cask candidate: $CASK_TOKEN"
  (
    cd "$HOMEBREW_CASK_DIR"
    export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
    export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
    run_timed "$AUDIT_TIMEOUT" "$BREW_BIN" audit --new --cask "$CASK_TOKEN"
  )
fi

log "official Homebrew Cask candidate ready: $CASK_PATH"
