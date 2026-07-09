#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

XCODE_PROJECT="${XCODE_PROJECT:-HoldType.xcodeproj}"
XCODE_SCHEME="${XCODE_SCHEME:-HoldType}"
APP_NAME="${APP_NAME:-HoldType}"
RELEASE_ROOT="${RELEASE_ROOT:-$REPO_ROOT/dist/release}"

log() {
  printf '[release] %s\n' "$*"
}

die() {
  printf '[release:error] %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    die "missing required environment variable: $name"
  fi
}

release_version_from_tag() {
  local tag="$1"
  printf '%s\n' "${tag#v}"
}

release_tag_for_version() {
  local version="$1"
  printf 'v%s\n' "$version"
}

validate_release_version() {
  local version="$1"
  if [ -z "$version" ]; then
    die "version must be non-empty and must not include a leading v"
  fi
  if [[ "$version" == v* ]]; then
    die "version must be non-empty and must not include a leading v"
  fi
  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,3}(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
    die "version must be a numeric public version like 1.0.0 or 1.0.0-beta.1"
  fi
}

validate_build_number() {
  local build="$1"
  if [[ ! "$build" =~ ^[0-9]+$ ]] || [[ "$build" =~ ^0+$ ]]; then
    die "build must be a positive integer string"
  fi
}

validate_repository_slug() {
  local name="$1"
  local value="$2"
  local owner="${value%%/*}"
  local repo_name="${value#*/}"

  if [ -z "$owner" ] || [ -z "$repo_name" ] || [ "$owner" = "$value" ]; then
    die "$name must be OWNER/REPO, got: $value"
  fi
  if [[ "$owner" == *" "* ]] || [[ "$repo_name" == *" "* ]] || [[ "$repo_name" == */* ]]; then
    die "$name must be OWNER/REPO, got: $value"
  fi
}

validate_homebrew_macos_requirement() {
  local value="$1"
  if [[ ! "$value" =~ ^(\>=|>|<=|<|==)[[:space:]]:[a-z][a-z0-9_]*$ ]]; then
    die "minimum macOS must be a Homebrew comparison expression such as: >= :sonoma"
  fi
}

sha256_for_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

run_timed() {
  local timeout_seconds="$1"
  shift
  "$SCRIPT_DIR/with_timeout.py" "$timeout_seconds" "$@"
}

safe_rm_generated_dir() {
  local dir="$1"
  local parent
  parent="$(dirname "$dir")"
  mkdir -p "$parent"
  local canonical
  canonical="$(cd "$parent" && pwd)/$(basename "$dir")"
  local release_root_canonical
  mkdir -p "$RELEASE_ROOT"
  release_root_canonical="$(cd "$RELEASE_ROOT" && pwd)"
  case "$canonical" in
    "$release_root_canonical"/*)
      rm -rf "$canonical"
      ;;
    *)
      die "refusing to remove directory outside release root: $canonical"
      ;;
  esac
}

find_generate_appcast() {
  if [ -n "${SPARKLE_GENERATE_APPCAST_PATH:-}" ]; then
    [ -x "$SPARKLE_GENERATE_APPCAST_PATH" ] || die "SPARKLE_GENERATE_APPCAST_PATH is not executable"
    printf '%s\n' "$SPARKLE_GENERATE_APPCAST_PATH"
    return
  fi

  local search_roots=()
  if [ -n "${DERIVED_DATA_DIR:-}" ]; then
    search_roots+=("$DERIVED_DATA_DIR")
  fi
  search_roots+=("$HOME/Library/Developer/Xcode/DerivedData")

  local candidate
  for root in "${search_roots[@]}"; do
    [ -d "$root" ] || continue
    candidate="$(
      find "$root" \
        -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' \
        -type f 2>/dev/null | head -n 1
    )"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  die "could not find Sparkle generate_appcast; run xcodebuild -resolvePackageDependencies or set SPARKLE_GENERATE_APPCAST_PATH"
}

notary_credentials_args() {
  if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    printf '%s\n' "--keychain-profile"
    printf '%s\n' "$NOTARY_KEYCHAIN_PROFILE"
    return
  fi

  require_env APP_STORE_CONNECT_API_KEY_PATH
  require_env APP_STORE_CONNECT_KEY_ID
  require_env APP_STORE_CONNECT_ISSUER_ID

  printf '%s\n' "--key"
  printf '%s\n' "$APP_STORE_CONNECT_API_KEY_PATH"
  printf '%s\n' "--key-id"
  printf '%s\n' "$APP_STORE_CONNECT_KEY_ID"
  printf '%s\n' "--issuer"
  printf '%s\n' "$APP_STORE_CONNECT_ISSUER_ID"
}
