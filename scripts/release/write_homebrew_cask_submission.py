#!/usr/bin/env python3
"""Write the official Homebrew Cask submission bundle for a public release."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


APP_NAME = "HoldType"
CASK_TOKEN = "holdtype"
OFFICIAL_HOMEBREW_CASK_PATH = f"Casks/{CASK_TOKEN[0]}/{CASK_TOKEN}.rb"
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
HOMEBREW_MACOS_COMPARISON_PATTERN = re.compile(r"^(>=|>|<=|<|==) :[a-z][a-z0-9_]*$")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def fail(message: str) -> int:
    print(f"[fail] homebrew-cask-submission: {message}", file=sys.stderr)
    return 1


def sha256_for_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_artifact_path(raw_path: str, release_dir: Path) -> Path:
    path = Path(raw_path)
    if path.is_absolute():
        return path
    candidates = (
        release_dir / path,
        release_dir / path.name,
        repo_root() / path,
        Path.cwd() / path,
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return release_dir / path.name


def is_artifact_filename(raw_path: str) -> bool:
    path = Path(raw_path)
    return bool(raw_path) and not path.is_absolute() and path.name == raw_path


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("manifest root must be a JSON object")
    return data


def release_metadata(
    *,
    release_dir: Path,
    repository: str,
    download_url_prefix: str,
) -> dict[str, str]:
    manifest_path = release_dir / "release-manifest.json"
    if not manifest_path.exists():
        raise ValueError(f"missing {manifest_path}")

    manifest = load_manifest(manifest_path)
    version = str(manifest.get("version", ""))
    tag = str(manifest.get("tag", ""))
    if not version:
        raise ValueError("manifest is missing version")
    if tag != f"v{version}":
        raise ValueError(f"manifest tag must be v{version}, got {tag!r}")
    if manifest.get("kind") != "public-release":
        raise ValueError("manifest kind must be public-release")
    if manifest.get("public_release") is not True:
        raise ValueError("manifest public_release must be true")
    if manifest.get("notarized") is not True:
        raise ValueError("manifest notarized must be true")

    dmg = manifest.get("dmg")
    if not isinstance(dmg, dict):
        raise ValueError("manifest is missing dmg object")

    raw_dmg_path = str(dmg.get("path", ""))
    expected_sha = str(dmg.get("sha256", "")).lower()
    if not SHA256_PATTERN.fullmatch(expected_sha):
        raise ValueError("manifest dmg.sha256 must be a 64-character hex digest")

    dmg_path = resolve_artifact_path(raw_dmg_path, release_dir)
    expected_dmg_name = f"{APP_NAME}-{version}.dmg"
    if raw_dmg_path != expected_dmg_name:
        if is_artifact_filename(raw_dmg_path):
            raise ValueError(f"manifest dmg.path must be {expected_dmg_name}, got {raw_dmg_path!r}")
        raise ValueError(
            f"manifest dmg.path must be artifact filename {expected_dmg_name}, got {raw_dmg_path!r}"
        )
    if dmg_path.name != expected_dmg_name:
        raise ValueError(f"expected DMG name {expected_dmg_name}, got {dmg_path.name}")
    if not dmg_path.exists():
        raise ValueError(f"missing DMG artifact: {dmg_path}")

    actual_sha = sha256_for_file(dmg_path)
    if actual_sha != expected_sha:
        raise ValueError(f"DMG sha256 mismatch: expected {expected_sha}, got {actual_sha}")

    prefix = download_url_prefix or f"https://github.com/{repository}/releases/download/{tag}/"
    dmg_url = f"{prefix.rstrip('/')}/{expected_dmg_name}"
    return {
        "version": version,
        "tag": tag,
        "dmg_path": str(dmg_path),
        "dmg_name": expected_dmg_name,
        "dmg_sha256": actual_sha,
        "dmg_url": dmg_url,
    }


def validate_homebrew_minimum_macos(value: str) -> bool:
    return bool(HOMEBREW_MACOS_COMPARISON_PATTERN.fullmatch(value))


def validate_repository_slug(value: str) -> bool:
    parts = value.split("/", 1)
    return (
        len(parts) == 2
        and bool(parts[0])
        and bool(parts[1])
        and " " not in parts[0]
        and " " not in parts[1]
        and "/" not in parts[1]
    )


def write_submission_markdown(
    *,
    path: Path,
    repository: str,
    metadata: dict[str, str],
    minimum_macos: str,
) -> None:
    version = metadata["version"]
    text = f"""# Official Homebrew Cask Submission: HoldType {version}

This bundle is for the later official `Homebrew/homebrew-cask` submission that
enables fresh installs with:

```sh
brew install --cask {CASK_TOKEN}
```

## Release Evidence

- Repository: `{repository}`
- Tag: `{metadata["tag"]}`
- DMG URL: `{metadata["dmg_url"]}`
- DMG SHA-256: `{metadata["dmg_sha256"]}`
- Minimum macOS: `{minimum_macos}`
- Candidate cask: `{OFFICIAL_HOMEBREW_CASK_PATH}`

## Upstream PR Path

Use this only after the public GitHub Release DMG is live, stable, signed, and
notarized.

The preferred path is to run the bundle wrapper from the HoldType repository:

```sh
scripts/release/open_official_homebrew_cask_pr_from_bundle.sh \\
  --bundle-dir /path/to/holdtype-official-homebrew-cask-{version} \\
  --audit \\
  --style \\
  --fork-repository <github-user>/homebrew-cask \\
  --push \\
  --open-pr
```

The wrapper reads `metadata.json`, ensures the local `homebrew/cask` tap
checkout exists, and delegates to the lower-level command:

```sh
scripts/release/create_official_homebrew_cask_pr.sh \\
  --homebrew-cask-dir "$(brew --repository homebrew/cask)" \\
  --version {version} \\
  --sha256 {metadata["dmg_sha256"]} \\
  --repository {repository} \\
  --minimum-macos "{minimum_macos}" \\
  --audit \\
  --style \\
  --fork-repository <github-user>/homebrew-cask \\
  --push \\
  --open-pr
```

Homebrew review checks to run from the `Homebrew/homebrew-cask` checkout:

```sh
cd "$(brew --repository homebrew/cask)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1
brew install --cask {CASK_TOKEN}
brew uninstall --cask {CASK_TOKEN}
brew style --fix {CASK_TOKEN}
brew audit --new --cask {CASK_TOKEN}
```

If the cask is accepted, later releases should use:

```sh
scripts/release/bump_official_homebrew_cask_pr.sh \\
  --version <next-version> \\
  --sha256 <sha256-of-next-dmg> \\
  --repository {repository}
```
"""
    path.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-dir", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--download-url-prefix", default="")
    parser.add_argument("--homepage", default="")
    parser.add_argument("--minimum-macos", default=os.environ.get("HOMEBREW_MINIMUM_MACOS", ""))
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    if not args.repository:
        return fail("missing --repository or GITHUB_REPOSITORY")
    if not validate_repository_slug(args.repository):
        return fail(f"--repository must be OWNER/REPO, got {args.repository!r}")
    if not args.minimum_macos:
        return fail("missing --minimum-macos or HOMEBREW_MINIMUM_MACOS")
    if not validate_homebrew_minimum_macos(args.minimum_macos):
        return fail('minimum macOS must be a Homebrew comparison expression such as ">= :tahoe"')

    release_dir = Path(args.release_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    try:
        metadata = release_metadata(
            release_dir=release_dir,
            repository=args.repository,
            download_url_prefix=args.download_url_prefix,
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return fail(str(error))

    cask_path = output_dir / OFFICIAL_HOMEBREW_CASK_PATH
    output_dir.mkdir(parents=True, exist_ok=True)

    render_command = [
        str(repo_root() / "scripts" / "release" / "render_homebrew_cask.sh"),
        "--version",
        metadata["version"],
        "--sha256",
        metadata["dmg_sha256"],
        "--repository",
        args.repository,
        "--minimum-macos",
        args.minimum_macos,
        "--output",
        str(cask_path),
    ]
    if args.homepage:
        render_command.extend(["--homepage", args.homepage])

    verify_command = [
        str(repo_root() / "scripts" / "release" / "verify_homebrew_cask.py"),
        "--cask-path",
        str(cask_path),
        "--version",
        metadata["version"],
        "--sha256",
        metadata["dmg_sha256"],
        "--repository",
        args.repository,
        "--minimum-macos",
        args.minimum_macos,
        "--require-minimum-macos",
        "--official-layout",
        "--quiet",
    ]
    if args.homepage:
        verify_command.extend(["--homepage", args.homepage])

    try:
        subprocess.run(render_command, cwd=repo_root(), text=True, check=True)
        subprocess.run(verify_command, cwd=repo_root(), text=True, check=True)
    except subprocess.CalledProcessError as error:
        return fail(f"{Path(error.cmd[0]).name} exited {error.returncode}")

    metadata_path = output_dir / "metadata.json"
    metadata_path.write_text(
        json.dumps(
            {
                "app": APP_NAME,
                "cask_token": CASK_TOKEN,
                "repository": args.repository,
                "version": metadata["version"],
                "tag": metadata["tag"],
                "dmg_url": metadata["dmg_url"],
                "dmg_sha256": metadata["dmg_sha256"],
                "minimum_macos": args.minimum_macos,
                "cask_path": OFFICIAL_HOMEBREW_CASK_PATH,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    write_submission_markdown(
        path=output_dir / "SUBMISSION.md",
        repository=args.repository,
        metadata=metadata,
        minimum_macos=args.minimum_macos,
    )

    print(f"[pass] homebrew-cask-submission:cask: {cask_path}")
    print(f"[pass] homebrew-cask-submission:metadata: {metadata_path}")
    print(f"[pass] homebrew-cask-submission:bundle: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
