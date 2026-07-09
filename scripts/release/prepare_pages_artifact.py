#!/usr/bin/env python3
"""Build one complete GitHub Pages artifact for the site and Sparkle feed."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


APP_NAME = "HoldType"
PUBLIC_WEBSITE_FILES = ("index.html", "styles.css", "script.js")
NOTES_FILENAME_PATTERN = re.compile(
    r"^HoldType-(?P<version>[0-9][0-9A-Za-z.-]*)\.md$"
)
PLACEHOLDER_PATTERN = re.compile(
    r"\b(TODO|TBD|FIXME|CHANGEME)\b|"
    r"<(?:version|summary|notes?|date|sha256|owner|repo|url)[^>\n]*>",
    re.IGNORECASE,
)
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


class PagesArtifactError(RuntimeError):
    """Raised when a complete Pages artifact cannot be constructed safely."""


def log(message: str) -> None:
    print(f"[release] {message}")


def validate_repository(value: str) -> str:
    owner, separator, repository = value.partition("/")
    if not separator or not owner or not repository or "/" in repository:
        raise PagesArtifactError(f"invalid GitHub repository: {value!r}")
    return value


def release_note_targets(appcast_path: Path, *, pages_base_url: str) -> dict[str, str]:
    try:
        root = ET.parse(appcast_path).getroot()
    except (ET.ParseError, OSError) as error:
        raise PagesArtifactError(f"could not parse appcast {appcast_path}: {error}") from error

    expected_base = urllib.parse.urlparse(pages_base_url)
    if expected_base.scheme != "https" or not expected_base.netloc:
        raise PagesArtifactError(f"Pages base URL must use HTTPS: {pages_base_url!r}")
    expected_path = expected_base.path.rstrip("/") + "/"

    targets: dict[str, str] = {}
    for item in root.findall(".//item"):
        notes_element = item.find(f"{{{SPARKLE_NAMESPACE}}}releaseNotesLink")
        version_element = item.find(f"{{{SPARKLE_NAMESPACE}}}shortVersionString")
        link = (notes_element.text or "").strip() if notes_element is not None else ""
        appcast_version = (
            (version_element.text or "").strip() if version_element is not None else ""
        )
        parsed = urllib.parse.urlparse(link)
        path_parts = tuple(part for part in parsed.path.split("/") if part)
        if ".." in path_parts:
            raise PagesArtifactError(f"unsafe Sparkle release notes URL: {link!r}")
        filename = Path(parsed.path).name
        match = NOTES_FILENAME_PATTERN.fullmatch(filename)
        if not link or match is None:
            raise PagesArtifactError(f"unsupported Sparkle release notes URL: {link!r}")
        version = match.group("version")
        if ".." in version:
            raise PagesArtifactError(f"unsafe release notes version: {version!r}")
        if appcast_version != version:
            raise PagesArtifactError(
                "Sparkle release notes version does not match "
                f"shortVersionString: {filename!r} vs {appcast_version!r}"
            )
        if (
            parsed.scheme != "https"
            or parsed.netloc != expected_base.netloc
            or parsed.path != f"{expected_path}{filename}"
        ):
            raise PagesArtifactError(
                f"Sparkle release notes URL is outside {pages_base_url!r}: {link!r}"
            )
        previous = targets.get(filename)
        if previous is not None and previous != version:
            raise PagesArtifactError(f"conflicting release notes target: {filename}")
        targets[filename] = version

    if not targets:
        raise PagesArtifactError("appcast does not contain Sparkle release notes links")
    return targets


def github_release_body(
    *,
    repository: str,
    version: str,
    api_url: str,
    token: str,
    timeout: int,
) -> str:
    tag = urllib.parse.quote(f"v{version}", safe="")
    url = f"{api_url.rstrip('/')}/repos/{repository}/releases/tags/{tag}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "holdtype-pages-artifact-builder",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        raise PagesArtifactError(
            f"could not fetch release notes for v{version}: HTTP {error.code}"
        ) from error
    except (OSError, json.JSONDecodeError) as error:
        raise PagesArtifactError(f"could not fetch release notes for v{version}: {error}") from error

    if not isinstance(payload, dict):
        raise PagesArtifactError(f"invalid GitHub Release response for v{version}")
    expected_tag = f"v{version}"
    if payload.get("tag_name") != expected_tag:
        raise PagesArtifactError(
            f"GitHub Release tag mismatch for v{version}: {payload.get('tag_name')!r}"
        )
    if payload.get("draft") is True or payload.get("prerelease") is True:
        raise PagesArtifactError(f"GitHub Release v{version} is not a stable public release")
    body = payload.get("body")
    if not isinstance(body, str) or not body.strip():
        raise PagesArtifactError(f"GitHub Release v{version} has no release notes body")
    return validate_release_notes(body, version=version)


def validate_release_notes(text: str, *, version: str) -> str:
    normalized = text.replace("\r\n", "\n").strip()
    lines = [line.strip() for line in normalized.splitlines() if line.strip()]
    expected_heading = f"# {APP_NAME} {version}"
    if not lines or lines[0] != expected_heading:
        actual = lines[0] if lines else ""
        raise PagesArtifactError(
            f"release notes for v{version} must start with {expected_heading!r}; got {actual!r}"
        )
    if len(lines) < 2:
        raise PagesArtifactError(f"release notes for v{version} have no body")
    placeholder = PLACEHOLDER_PATTERN.search(normalized)
    if placeholder is not None:
        raise PagesArtifactError(
            f"release notes for v{version} contain placeholder {placeholder.group(0)!r}"
        )
    return normalized + "\n"


def reject_symlinks(path: Path) -> None:
    if path.is_symlink():
        raise PagesArtifactError(f"public website source must not be a symlink: {path}")
    if path.is_dir():
        for descendant in path.rglob("*"):
            if descendant.is_symlink():
                raise PagesArtifactError(
                    f"public website source must not contain symlinks: {descendant}"
                )


def prepare_artifact(
    *,
    website_dir: Path,
    appcast_path: Path,
    output_dir: Path,
    repository: str,
    api_url: str,
    token: str,
    timeout: int,
    current_version: str | None,
    current_notes_path: Path | None,
    pages_base_url: str,
) -> list[Path]:
    validate_repository(repository)
    if timeout <= 0:
        raise PagesArtifactError("timeout must be greater than zero")
    if (current_version is None) != (current_notes_path is None):
        raise PagesArtifactError(
            "--current-version and --current-release-notes must be supplied together"
        )
    if not website_dir.is_dir():
        raise PagesArtifactError(f"website directory not found: {website_dir}")
    if not appcast_path.is_file():
        raise PagesArtifactError(f"appcast not found: {appcast_path}")
    if output_dir.exists():
        if not output_dir.is_dir():
            raise PagesArtifactError(f"output path is not a directory: {output_dir}")
        if any(output_dir.iterdir()):
            raise PagesArtifactError(f"output directory must be empty: {output_dir}")

    targets = release_note_targets(appcast_path, pages_base_url=pages_base_url)
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for filename in PUBLIC_WEBSITE_FILES:
        source = website_dir / filename
        if not source.is_file():
            raise PagesArtifactError(f"public website file not found: {source}")
        reject_symlinks(source)
        destination = output_dir / filename
        shutil.copy2(source, destination)
        written.append(destination)

    assets_source = website_dir / "assets"
    if not assets_source.is_dir():
        raise PagesArtifactError(f"website assets directory not found: {assets_source}")
    reject_symlinks(assets_source)
    assets_destination = output_dir / "assets"
    shutil.copytree(assets_source, assets_destination)
    written.extend(path for path in assets_destination.rglob("*") if path.is_file())

    appcast_destination = output_dir / "appcast.xml"
    shutil.copy2(appcast_path, appcast_destination)
    written.append(appcast_destination)

    current_notes_text: str | None = None
    if current_notes_path is not None:
        if not current_notes_path.is_file():
            raise PagesArtifactError(f"current release notes not found: {current_notes_path}")
        current_notes_text = current_notes_path.read_text()
        if not current_notes_text.strip():
            raise PagesArtifactError(f"current release notes are empty: {current_notes_path}")

    for filename, version in sorted(targets.items()):
        if version == current_version and current_notes_text is not None:
            notes = validate_release_notes(current_notes_text, version=version)
        else:
            notes = github_release_body(
                repository=repository,
                version=version,
                api_url=api_url,
                token=token,
                timeout=timeout,
            )
        destination = output_dir / filename
        destination.write_text(notes)
        written.append(destination)

    nojekyll = output_dir / ".nojekyll"
    nojekyll.write_text("")
    written.append(nojekyll)
    return sorted(written)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--website-dir", required=True)
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--pages-base-url", required=True)
    parser.add_argument("--github-api-url", default="https://api.github.com")
    parser.add_argument("--github-token-env", default="GITHUB_TOKEN")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--current-version")
    parser.add_argument("--current-release-notes")
    args = parser.parse_args()

    try:
        written = prepare_artifact(
            website_dir=Path(args.website_dir),
            appcast_path=Path(args.appcast),
            output_dir=Path(args.output_dir),
            repository=args.repository,
            api_url=args.github_api_url,
            token=os.environ.get(args.github_token_env, ""),
            timeout=args.timeout,
            current_version=args.current_version,
            current_notes_path=(
                Path(args.current_release_notes) if args.current_release_notes else None
            ),
            pages_base_url=args.pages_base_url,
        )
    except PagesArtifactError as error:
        print(f"[release:error] {error}", file=sys.stderr)
        return 1

    log(f"Pages artifact ready: {args.output_dir} ({len(written)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
