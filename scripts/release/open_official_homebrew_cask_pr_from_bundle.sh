#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/open_official_homebrew_cask_pr_from_bundle.sh \
    --bundle-dir /path/to/holdtype-official-homebrew-cask-1.0.0 \
    --fork-repository github-user/homebrew-cask --push --open-pr

Options:
  --bundle-dir PATH              Official cask submission bundle directory.
  --homebrew-cask-dir PATH       Local Homebrew/homebrew-cask checkout.
                                 Defaults to `brew --repository homebrew/cask`
                                 after `brew tap --force homebrew/cask`.
  --fork-repository OWNER/REPO   Fork used as the PR head repository.
  --base-repository OWNER/REPO   Defaults to Homebrew/homebrew-cask.
  --base-branch BRANCH           Defaults to main.
  --branch BRANCH                Defaults to holdtype-VERSION.
  --homepage URL
  --audit                        Run brew audit --new --cask holdtype.
  --style                        Run brew style --fix holdtype.
  --push                         Push HEAD to the fork branch.
  --open-pr                      Open or reuse a PR against Homebrew/homebrew-cask.
  --push-url URL                 Push URL override; may contain a token.
  --git-user-name NAME           Configure git user.name in the cask checkout.
  --git-user-email EMAIL         Configure git user.email in the cask checkout.
  --brew PATH                    Defaults to BREW_BIN or brew.
  --gh PATH                      Defaults to GH_BIN or gh.
  --git PATH                     Defaults to GIT_BIN or git.
  --tap-timeout SECONDS          Defaults to 300.
  --audit-timeout SECONDS        Defaults to 600.
  --style-timeout SECONDS        Defaults to 300.
  --push-timeout SECONDS         Defaults to 300.
  --pr-timeout SECONDS           Defaults to 300.
  --help

This is the first official Homebrew Cask submission wrapper. It reads the
release version, SHA-256, repository, and minimum macOS value from the
submission bundle metadata written by write_homebrew_cask_submission.py, then
delegates to create_official_homebrew_cask_pr.sh.
USAGE
}

metadata_value() {
  local key="$1"
  python3 - "$METADATA_PATH" "$key" <<'PY' || die "metadata field not readable: $key"
from __future__ import annotations

import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit("metadata root must be an object")
value = data.get(key)
if not isinstance(value, str) or not value:
    raise SystemExit(f"missing string field: {key}")
print(value)
PY
}

BUNDLE_DIR=""
HOMEBREW_CASK_DIR=""
FORK_REPOSITORY="${HOMEBREW_CASK_FORK_REPOSITORY:-}"
BASE_REPOSITORY="${HOMEBREW_CASK_BASE_REPOSITORY:-Homebrew/homebrew-cask}"
BASE_BRANCH="${HOMEBREW_CASK_BASE_BRANCH:-main}"
BRANCH=""
HOMEPAGE=""
AUDIT=0
STYLE=0
PUSH=0
OPEN_PR=0
PUSH_URL=""
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
BREW_BIN="${BREW_BIN:-brew}"
GH_BIN="${GH_BIN:-gh}"
GIT_BIN="${GIT_BIN:-git}"
TAP_TIMEOUT=300
AUDIT_TIMEOUT=600
STYLE_TIMEOUT=300
PUSH_TIMEOUT=300
PR_TIMEOUT=300
CASK_TOKEN="holdtype"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle-dir)
      BUNDLE_DIR="$2"
      shift 2
      ;;
    --homebrew-cask-dir)
      HOMEBREW_CASK_DIR="$2"
      shift 2
      ;;
    --fork-repository)
      FORK_REPOSITORY="$2"
      shift 2
      ;;
    --base-repository)
      BASE_REPOSITORY="$2"
      shift 2
      ;;
    --base-branch)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --homepage)
      HOMEPAGE="$2"
      shift 2
      ;;
    --audit)
      AUDIT=1
      shift
      ;;
    --style)
      STYLE=1
      shift
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --open-pr)
      OPEN_PR=1
      PUSH=1
      shift
      ;;
    --push-url)
      PUSH_URL="$2"
      shift 2
      ;;
    --git-user-name)
      GIT_USER_NAME="$2"
      shift 2
      ;;
    --git-user-email)
      GIT_USER_EMAIL="$2"
      shift 2
      ;;
    --brew)
      BREW_BIN="$2"
      shift 2
      ;;
    --gh)
      GH_BIN="$2"
      shift 2
      ;;
    --git)
      GIT_BIN="$2"
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
    --style-timeout)
      STYLE_TIMEOUT="$2"
      shift 2
      ;;
    --push-timeout)
      PUSH_TIMEOUT="$2"
      shift 2
      ;;
    --pr-timeout)
      PR_TIMEOUT="$2"
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

[ -n "$BUNDLE_DIR" ] || die "missing --bundle-dir"
[ -d "$BUNDLE_DIR" ] || die "submission bundle not found: $BUNDLE_DIR"

METADATA_PATH="$BUNDLE_DIR/metadata.json"
[ -f "$METADATA_PATH" ] || die "submission bundle metadata not found: $METADATA_PATH"

CASK_TOKEN_METADATA="$(metadata_value cask_token)"
CASK_PATH_METADATA="$(metadata_value cask_path)"
VERSION="$(metadata_value version)"
SHA256="$(metadata_value dmg_sha256)"
DMG_URL="$(metadata_value dmg_url)"
REPOSITORY="$(metadata_value repository)"
MINIMUM_MACOS="$(metadata_value minimum_macos)"

validate_release_version "$VERSION"
validate_repository_slug "metadata.repository" "$REPOSITORY"
validate_repository_slug "--base-repository" "$BASE_REPOSITORY"
validate_homebrew_macos_requirement "$MINIMUM_MACOS"

EXPECTED_CASK_PATH="Casks/${CASK_TOKEN:0:1}/$CASK_TOKEN.rb"
EXPECTED_DMG_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION/$APP_NAME-$VERSION.dmg"

[ "$CASK_TOKEN_METADATA" = "$CASK_TOKEN" ] || die "metadata.cask_token must be $CASK_TOKEN"
[ "$CASK_PATH_METADATA" = "$EXPECTED_CASK_PATH" ] || die "metadata.cask_path must be $EXPECTED_CASK_PATH"
[ "$DMG_URL" = "$EXPECTED_DMG_URL" ] || die "metadata.dmg_url must be $EXPECTED_DMG_URL"

case "$SHA256" in
  *[!0-9a-fA-F]*)
    die "metadata.dmg_sha256 must be a 64-character hex digest"
    ;;
esac
[ "${#SHA256}" -eq 64 ] || die "metadata.dmg_sha256 must be a 64-character hex digest"
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

BUNDLE_CASK_PATH="$BUNDLE_DIR/$EXPECTED_CASK_PATH"
[ -f "$BUNDLE_CASK_PATH" ] || die "submission bundle cask not found: $BUNDLE_CASK_PATH"

"$SCRIPT_DIR/verify_homebrew_cask.py" \
  --cask-path "$BUNDLE_CASK_PATH" \
  --version "$VERSION" \
  --sha256 "$SHA256" \
  --repository "$REPOSITORY" \
  --minimum-macos "$MINIMUM_MACOS" \
  --require-minimum-macos \
  --official-layout \
  --quiet

if [ -z "$HOMEBREW_CASK_DIR" ]; then
  require_command "$BREW_BIN"
  log "ensuring official Homebrew Cask tap checkout"
  run_timed "$TAP_TIMEOUT" "$BREW_BIN" tap --force homebrew/cask
  HOMEBREW_CASK_DIR="$(run_timed "$TAP_TIMEOUT" "$BREW_BIN" --repository homebrew/cask)"
fi

[ -d "$HOMEBREW_CASK_DIR" ] || die "Homebrew Cask checkout not found: $HOMEBREW_CASK_DIR"

create_args=(
  --homebrew-cask-dir "$HOMEBREW_CASK_DIR"
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
  --minimum-macos "$MINIMUM_MACOS"
  --base-repository "$BASE_REPOSITORY"
  --base-branch "$BASE_BRANCH"
  --brew "$BREW_BIN"
  --gh "$GH_BIN"
  --git "$GIT_BIN"
  --audit-timeout "$AUDIT_TIMEOUT"
  --style-timeout "$STYLE_TIMEOUT"
  --push-timeout "$PUSH_TIMEOUT"
  --pr-timeout "$PR_TIMEOUT"
)

if [ -n "$BRANCH" ]; then
  create_args+=(--branch "$BRANCH")
fi
if [ -n "$HOMEPAGE" ]; then
  create_args+=(--homepage "$HOMEPAGE")
fi
if [ -n "$FORK_REPOSITORY" ]; then
  create_args+=(--fork-repository "$FORK_REPOSITORY")
fi
if [ "$AUDIT" -eq 1 ]; then
  create_args+=(--audit)
fi
if [ "$STYLE" -eq 1 ]; then
  create_args+=(--style)
fi
if [ "$PUSH" -eq 1 ]; then
  create_args+=(--push)
fi
if [ "$OPEN_PR" -eq 1 ]; then
  create_args+=(--open-pr)
fi
if [ -n "$PUSH_URL" ]; then
  create_args+=(--push-url "$PUSH_URL")
fi
if [ -n "$GIT_USER_NAME" ]; then
  create_args+=(--git-user-name "$GIT_USER_NAME")
fi
if [ -n "$GIT_USER_EMAIL" ]; then
  create_args+=(--git-user-email "$GIT_USER_EMAIL")
fi

"$SCRIPT_DIR/create_official_homebrew_cask_pr.sh" "${create_args[@]}"
