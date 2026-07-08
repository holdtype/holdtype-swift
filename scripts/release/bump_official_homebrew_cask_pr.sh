#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/bump_official_homebrew_cask_pr.sh \
    --version 1.0.1 --sha256 SHA --repository owner/repo

Options:
  --version VERSION          New app version without leading v.
  --sha256 SHA256           SHA-256 of HoldType-VERSION.dmg.
  --repository OWNER/REPO   GitHub release repository.
  --url URL                 Override the release DMG URL.
  --cask-token TOKEN        Defaults to holdtype.
  --fork-org ORG            Passed to brew bump-cask-pr --fork-org.
  --dry-run                 Passed to brew bump-cask-pr --dry-run.
  --no-audit                Passed to brew bump-cask-pr --no-audit.
  --no-style                Passed to brew bump-cask-pr --no-style.
  --brew PATH               Defaults to BREW_BIN or brew.
  --tap-timeout SECONDS     Defaults to 300.
  --timeout SECONDS         Defaults to 900.
  --help

Use this only after the initial HoldType cask has been accepted into
Homebrew/homebrew-cask. For the first upstream submission, use
create_official_homebrew_cask_pr.sh instead.
USAGE
}

validate_release_dmg_url() {
  local url="$1"
  local expected_file="$APP_NAME-$VERSION.dmg"

  case "$url" in
    https://*)
      ;;
    *)
      die "--url must use https: $url"
      ;;
  esac

  case "$url" in
    *"/releases/download/v$VERSION/"*)
      ;;
    *)
      die "--url must include /releases/download/v$VERSION/: $url"
      ;;
  esac

  case "$url" in
    *"/$expected_file")
      ;;
    *)
      die "--url must end with $expected_file: $url"
      ;;
  esac
}

VERSION=""
SHA256=""
REPOSITORY="${GITHUB_REPOSITORY:-}"
URL=""
CASK_TOKEN="holdtype"
FORK_ORG=""
DRY_RUN=0
NO_AUDIT=0
NO_STYLE=0
BREW_BIN="${BREW_BIN:-brew}"
TAP_TIMEOUT=300
TIMEOUT=900

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
    --url)
      URL="$2"
      shift 2
      ;;
    --cask-token)
      CASK_TOKEN="$2"
      shift 2
      ;;
    --fork-org)
      FORK_ORG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-audit)
      NO_AUDIT=1
      shift
      ;;
    --no-style)
      NO_STYLE=1
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
    --timeout)
      TIMEOUT="$2"
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
[ -n "$CASK_TOKEN" ] || die "missing --cask-token"

validate_release_version "$VERSION"
validate_repository_slug "--repository" "$REPOSITORY"

case "$SHA256" in
  *[!0-9a-fA-F]*)
    die "sha256 must be a 64-character hex digest"
    ;;
esac
[ "${#SHA256}" -eq 64 ] || die "sha256 must be a 64-character hex digest"
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

URL="${URL:-https://github.com/$REPOSITORY/releases/download/v$VERSION/$APP_NAME-$VERSION.dmg}"
validate_release_dmg_url "$URL"

require_command "$BREW_BIN"

export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
log "ensuring official Homebrew Cask tap checkout"
run_timed "$TAP_TIMEOUT" "$BREW_BIN" tap --force homebrew/cask

args=(
  bump-cask-pr
  --version "$VERSION"
  --url "$URL"
  --sha256 "$SHA256"
  --no-browse
)
if [ -n "$FORK_ORG" ]; then
  args+=(--fork-org "$FORK_ORG")
fi
if [ "$DRY_RUN" -eq 1 ]; then
  args+=(--dry-run)
fi
if [ "$NO_AUDIT" -eq 1 ]; then
  args+=(--no-audit)
fi
if [ "$NO_STYLE" -eq 1 ]; then
  args+=(--no-style)
fi
args+=("$CASK_TOKEN")

log "opening official Homebrew Cask bump PR for $CASK_TOKEN $VERSION"
run_timed "$TIMEOUT" "$BREW_BIN" "${args[@]}"
