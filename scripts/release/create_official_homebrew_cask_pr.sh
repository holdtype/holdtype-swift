#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/release/create_official_homebrew_cask_pr.sh \
    --homebrew-cask-dir "$(brew --repository homebrew/cask)" \
    --version 1.0.0 --sha256 SHA --repository owner/repo \
    --minimum-macos ">= :tahoe" \
    --fork-repository github-user/homebrew-cask --push --open-pr

Options:
  --homebrew-cask-dir PATH       Local Homebrew/homebrew-cask checkout.
  --version VERSION
  --sha256 SHA256
  --repository OWNER/REPO
  --fork-repository OWNER/REPO   Fork used as the PR head repository.
  --base-repository OWNER/REPO   Defaults to Homebrew/homebrew-cask.
  --base-branch BRANCH           Defaults to main.
  --branch BRANCH                Defaults to holdtype-VERSION.
  --homepage URL
  --minimum-macos HOMEBREW_VALUE Required. Example: ">= :tahoe"
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
  --audit-timeout SECONDS        Defaults to 600.
  --style-timeout SECONDS        Defaults to 300.
  --push-timeout SECONDS         Defaults to 300.
  --pr-timeout SECONDS           Defaults to 300.
  --help

The script creates a local new-cask commit for the official Homebrew Cask
repository. It only pushes or opens a PR when explicitly requested.
USAGE
}

ensure_clean_checkout() {
  local status
  status="$("$GIT_BIN" -C "$HOMEBREW_CASK_DIR" status --porcelain)"
  [ -z "$status" ] || die "Homebrew Cask checkout has uncommitted changes"
}

find_base_ref() {
  local candidate
  for candidate in "origin/$BASE_BRANCH" "$BASE_BRANCH"; do
    if "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" rev-parse --verify --quiet "$candidate^{commit}" >/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_cask_absent_from_base() {
  local cask_path="$1"
  local base_ref
  base_ref="$(find_base_ref || true)"
  if [ -z "$base_ref" ]; then
    log "could not find base ref $BASE_BRANCH; skipping existing official cask guard"
    return 0
  fi

  if "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" cat-file -e "$base_ref:$cask_path" 2>/dev/null; then
    die "official Homebrew Cask already exists on $base_ref at $cask_path; use bump_official_homebrew_cask_pr.sh"
  fi
}

verify_rendered_cask() {
  local verify_args=(
    --cask-path "$HOMEBREW_CASK_DIR/$CASK_PATH"
    --version "$VERSION"
    --sha256 "$SHA256"
    --repository "$REPOSITORY"
    --official-layout
    --minimum-macos "$MINIMUM_MACOS"
    --require-minimum-macos
  )
  if [ -n "$HOMEPAGE" ]; then
    verify_args+=(--homepage "$HOMEPAGE")
  fi
  "$SCRIPT_DIR/verify_homebrew_cask.py" "${verify_args[@]}" --quiet
}

HOMEBREW_CASK_DIR=""
VERSION=""
SHA256=""
REPOSITORY="${GITHUB_REPOSITORY:-}"
FORK_REPOSITORY="${HOMEBREW_CASK_FORK_REPOSITORY:-}"
BASE_REPOSITORY="${HOMEBREW_CASK_BASE_REPOSITORY:-Homebrew/homebrew-cask}"
BASE_BRANCH="${HOMEBREW_CASK_BASE_BRANCH:-main}"
BRANCH=""
HOMEPAGE=""
MINIMUM_MACOS="${HOMEBREW_MINIMUM_MACOS:-}"
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
AUDIT_TIMEOUT=600
STYLE_TIMEOUT=300
PUSH_TIMEOUT=300
PR_TIMEOUT=300
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
    --minimum-macos)
      MINIMUM_MACOS="$2"
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

[ -n "$HOMEBREW_CASK_DIR" ] || die "missing --homebrew-cask-dir"
[ -d "$HOMEBREW_CASK_DIR" ] || die "Homebrew Cask checkout not found: $HOMEBREW_CASK_DIR"
[ -n "$VERSION" ] || die "missing --version"
[ -n "$SHA256" ] || die "missing --sha256"
[ -n "$REPOSITORY" ] || die "missing --repository"
[ -n "$MINIMUM_MACOS" ] || die "missing --minimum-macos or HOMEBREW_MINIMUM_MACOS"

validate_release_version "$VERSION"
validate_repository_slug "--repository" "$REPOSITORY"
validate_repository_slug "--base-repository" "$BASE_REPOSITORY"
validate_homebrew_macos_requirement "$MINIMUM_MACOS"

BRANCH="${BRANCH:-$CASK_TOKEN-$VERSION}"

require_command "$GIT_BIN"
if [ "$AUDIT" -eq 1 ] || [ "$STYLE" -eq 1 ]; then
  require_command "$BREW_BIN"
fi
if [ "$OPEN_PR" -eq 1 ]; then
  require_command "$GH_BIN"
fi
if [ "$PUSH" -eq 1 ]; then
  [ -n "$FORK_REPOSITORY" ] || die "missing --fork-repository for --push or --open-pr"
  validate_repository_slug "--fork-repository" "$FORK_REPOSITORY"
fi

"$GIT_BIN" -C "$HOMEBREW_CASK_DIR" rev-parse --is-inside-work-tree >/dev/null \
  || die "not a git checkout: $HOMEBREW_CASK_DIR"

ensure_clean_checkout
CASK_PATH="Casks/${CASK_TOKEN:0:1}/$CASK_TOKEN.rb"
ensure_cask_absent_from_base "$CASK_PATH"

if [ -n "$GIT_USER_NAME" ]; then
  "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" config user.name "$GIT_USER_NAME"
fi
if [ -n "$GIT_USER_EMAIL" ]; then
  "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" config user.email "$GIT_USER_EMAIL"
fi

if "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" checkout "$BRANCH"
else
  "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" checkout -b "$BRANCH"
fi

ensure_clean_checkout

prepare_args=(
  --homebrew-cask-dir "$HOMEBREW_CASK_DIR"
  --version "$VERSION"
  --sha256 "$SHA256"
  --repository "$REPOSITORY"
)
if [ -n "$HOMEPAGE" ]; then
  prepare_args+=(--homepage "$HOMEPAGE")
fi
prepare_args+=(--minimum-macos "$MINIMUM_MACOS")

"$SCRIPT_DIR/prepare_official_homebrew_cask.sh" "${prepare_args[@]}"

if [ "$STYLE" -eq 1 ]; then
  log "formatting official Homebrew Cask candidate: $CASK_TOKEN"
  (
    cd "$HOMEBREW_CASK_DIR"
    export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
    export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
    run_timed "$STYLE_TIMEOUT" "$BREW_BIN" style --fix "$CASK_TOKEN"
  )
  verify_rendered_cask
fi

if [ "$AUDIT" -eq 1 ]; then
  log "auditing official Homebrew Cask candidate: $CASK_TOKEN"
  (
    cd "$HOMEBREW_CASK_DIR"
    export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
    export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
    run_timed "$AUDIT_TIMEOUT" "$BREW_BIN" audit --new --cask "$CASK_TOKEN"
  )
fi

"$GIT_BIN" -C "$HOMEBREW_CASK_DIR" add "$CASK_PATH"

if "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" diff --cached --quiet; then
  log "official Homebrew Cask commit already up to date: $BRANCH"
else
  "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" commit -m "$CASK_TOKEN $VERSION (new cask)"
  log "created official Homebrew Cask commit: $BRANCH"
fi

if [ "$PUSH" -eq 1 ]; then
  if [ -z "$PUSH_URL" ]; then
    if [ -n "${HOMEBREW_CASK_PR_TOKEN:-}" ]; then
      PUSH_URL="https://x-access-token:${HOMEBREW_CASK_PR_TOKEN}@github.com/${FORK_REPOSITORY}.git"
    else
      PUSH_URL="https://github.com/${FORK_REPOSITORY}.git"
    fi
  fi
  log "pushing official Homebrew Cask branch: $BRANCH"
  run_timed "$PUSH_TIMEOUT" "$GIT_BIN" -C "$HOMEBREW_CASK_DIR" push "$PUSH_URL" "HEAD:$BRANCH"
fi

if [ "$OPEN_PR" -eq 1 ]; then
  fork_owner="${FORK_REPOSITORY%%/*}"
  pr_head="$fork_owner:$BRANCH"
  pr_title="$CASK_TOKEN $VERSION (new cask)"
  pr_body="Adds HoldType $VERSION as a new Homebrew Cask using the public GitHub Release DMG and pinned SHA-256."

  existing_pr_url="$(
    run_timed "$PR_TIMEOUT" "$GH_BIN" pr list \
      --repo "$BASE_REPOSITORY" \
      --base "$BASE_BRANCH" \
      --head "$pr_head" \
      --state open \
      --json url \
      --jq '.[0].url // ""'
  )"
  if [ -n "$existing_pr_url" ]; then
    log "official Homebrew Cask pull request already exists: $existing_pr_url"
  else
    run_timed "$PR_TIMEOUT" "$GH_BIN" pr create \
      --repo "$BASE_REPOSITORY" \
      --base "$BASE_BRANCH" \
      --head "$pr_head" \
      --title "$pr_title" \
      --body "$pr_body"
  fi
fi

log "official Homebrew Cask PR branch ready: $HOMEBREW_CASK_DIR@$BRANCH"
