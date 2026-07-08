#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/update_homebrew_tap.sh --tap-dir /path/to/homebrew-tap \
    --version 1.0.0 --sha256 SHA --repository owner/repo

Options:
  --tap-dir PATH
  --version VERSION
  --sha256 SHA256
  --repository OWNER/REPO
  --tap-repository OWNER/HOMEBREW_REPO  Used to derive brew tap name for audit.
  --tap-name OWNER/TAP                 Overrides derived tap name.
  --homepage URL
  --minimum-macos HOMEBREW_VALUE       Example: ">= :tahoe"
  --audit                              Run brew tap and brew audit after rendering.
  --brew PATH                          Defaults to BREW_BIN or brew.
  --tap-timeout SECONDS                Defaults to 300.
  --audit-timeout SECONDS              Defaults to 600.
  --help

The script updates Casks/holdtype.rb inside an existing tap checkout. It does
not clone, commit, push, or open a pull request.
USAGE
}

derive_tap_name() {
  local repository="$1"
  local owner="${repository%%/*}"
  local repo_name="${repository#*/}"

  if [ -z "$owner" ] || [ -z "$repo_name" ] || [ "$owner" = "$repository" ]; then
    die "tap repository must be OWNER/REPO, got: $repository"
  fi
  case "$repo_name" in
    homebrew-?*)
      ;;
    *)
      die "tap repository name must start with homebrew-, got: $repository"
      ;;
  esac

  printf '%s/%s\n' "$owner" "${repo_name#homebrew-}"
}

TAP_DIR=""
VERSION=""
SHA256=""
REPOSITORY="${GITHUB_REPOSITORY:-}"
TAP_REPOSITORY="${HOMEBREW_TAP_REPOSITORY:-}"
TAP_NAME=""
HOMEPAGE=""
MINIMUM_MACOS="${HOMEBREW_MINIMUM_MACOS:-}"
AUDIT=0
BREW_BIN="${BREW_BIN:-brew}"
TAP_TIMEOUT=300
AUDIT_TIMEOUT=600

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tap-dir)
      TAP_DIR="$2"
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
    --tap-repository)
      TAP_REPOSITORY="$2"
      shift 2
      ;;
    --tap-name)
      TAP_NAME="$2"
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
    --tap-timeout)
      TAP_TIMEOUT="$2"
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

[ -n "$TAP_DIR" ] || die "missing --tap-dir"
[ -n "$VERSION" ] || die "missing --version"
[ -n "$SHA256" ] || die "missing --sha256"
[ -n "$REPOSITORY" ] || die "missing --repository"

validate_release_version "$VERSION"

case "$SHA256" in
  *[!0-9a-fA-F]*)
    die "sha256 must be a 64-character hex digest"
    ;;
esac
[ "${#SHA256}" -eq 64 ] || die "sha256 must be a 64-character hex digest"
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

render_args=(
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
  --output "$TAP_DIR/Casks/holdtype.rb"
)

if [ -n "$HOMEPAGE" ]; then
  render_args+=(--homepage "$HOMEPAGE")
fi
if [ -n "$MINIMUM_MACOS" ]; then
  render_args+=(--minimum-macos "$MINIMUM_MACOS")
fi

"$SCRIPT_DIR/render_homebrew_cask.sh" "${render_args[@]}"

if [ "$AUDIT" -eq 1 ]; then
  require_command "$BREW_BIN"

  if [ -z "$TAP_NAME" ]; then
    [ -n "$TAP_REPOSITORY" ] || die "missing --tap-repository or --tap-name for --audit"
    TAP_NAME="$(derive_tap_name "$TAP_REPOSITORY")"
  fi

  log "auditing Homebrew cask through tap: $TAP_NAME"
  export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
  export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
  run_timed "$TAP_TIMEOUT" "$BREW_BIN" tap "$TAP_NAME" "$TAP_DIR"
  run_timed "$AUDIT_TIMEOUT" "$BREW_BIN" audit --new --cask "$TAP_NAME/holdtype"
fi

log "updated Homebrew tap cask: $TAP_DIR/Casks/holdtype.rb"
