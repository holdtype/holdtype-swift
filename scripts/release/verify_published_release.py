#!/usr/bin/env python3
"""Verify the externally published GitHub Release and appcast metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any


APP_NAME = "HoldType"
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
BUILD_PATTERN = re.compile(r"^[0-9]+$")


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def warn_check(name: str, message: str) -> Check:
    return Check(name=name, status="warn", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def print_checks(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def request_headers(token: str) -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "holdtype-release-verifier",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def fetch_bytes(url: str, *, timeout: int, token: str = "") -> bytes:
    request = urllib.request.Request(url, headers=request_headers(token))
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def fetch_json(url: str, *, timeout: int, token: str = "") -> Any:
    return json.loads(fetch_bytes(url, timeout=timeout, token=token).decode("utf-8"))


def download_sha256(url: str, *, timeout: int, token: str = "", output_path: Path | None = None) -> str:
    request = urllib.request.Request(url, headers=request_headers(token))
    digest = hashlib.sha256()
    handle = output_path.open("wb") if output_path is not None else tempfile.TemporaryFile()
    try:
        with handle:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                for chunk in iter(lambda: response.read(1024 * 1024), b""):
                    if not chunk:
                        break
                    digest.update(chunk)
                    handle.write(chunk)
    finally:
        if output_path is None:
            handle.close()
    return digest.hexdigest()


def release_api_url(api_base_url: str, repository: str, tag: str) -> str:
    base = api_base_url.rstrip("/")
    quoted_repo = "/".join(urllib.parse.quote(part, safe="") for part in repository.split("/", 1))
    return f"{base}/repos/{quoted_repo}/releases/tags/{urllib.parse.quote(tag, safe='')}"


def expected_asset_names(version: str) -> set[str]:
    return {
        f"{APP_NAME}-{version}.dmg",
        f"{APP_NAME}-{version}.zip",
        "SHA256SUMS.txt",
        "release-manifest.json",
        "appcast.xml",
    }


def index_assets(release: dict[str, Any]) -> dict[str, dict[str, Any]]:
    assets = release.get("assets", [])
    if not isinstance(assets, list):
        return {}
    indexed: dict[str, dict[str, Any]] = {}
    for asset in assets:
        if isinstance(asset, dict) and isinstance(asset.get("name"), str):
            indexed[asset["name"]] = asset
    return indexed


def check_unexpected_assets(
    release: dict[str, Any],
    *,
    expected_names: set[str],
) -> list[Check]:
    assets = release.get("assets", [])
    if not isinstance(assets, list):
        return []

    unexpected: list[str] = []
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = asset.get("name")
        if isinstance(name, str) and name and name not in expected_names:
            unexpected.append(name)

    if unexpected:
        return [fail_check("github-assets:unexpected", ", ".join(sorted(unexpected)))]
    return [pass_check("github-assets:unexpected", "none")]


def parse_sha256s(text: str) -> dict[str, tuple[str, str]]:
    entries: dict[str, tuple[str, str]] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2:
            continue
        sha256, raw_path = parts
        cleaned_path = raw_path.strip()
        entries[Path(cleaned_path).name] = (sha256.lower(), cleaned_path)
    return entries


def validate_sha256(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{64}", value.lower()))


def validate_build(value: str) -> bool:
    return bool(BUILD_PATTERN.fullmatch(value) and int(value) > 0)


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


def asset_download_url(asset: dict[str, Any]) -> str:
    value = asset.get("browser_download_url", "")
    return value if isinstance(value, str) else ""


def check_release_basics(
    release: dict[str, Any],
    *,
    download_url_prefix: str,
    tag: str,
    version: str,
) -> tuple[dict[str, dict[str, Any]], list[Check]]:
    checks: list[Check] = []
    html_url = release.get("html_url", "")
    if isinstance(html_url, str) and html_url:
        checks.append(pass_check("github-release", html_url))
    else:
        checks.append(fail_check("github-release", "missing html_url"))

    if release.get("tag_name") == tag:
        checks.append(pass_check("github-release:tag", tag))
    else:
        checks.append(fail_check("github-release:tag", f"expected {tag}, got {release.get('tag_name')!r}"))

    if release.get("draft") is False:
        checks.append(pass_check("github-release:draft", "false"))
    else:
        checks.append(fail_check("github-release:draft", f"expected false, got {release.get('draft')!r}"))

    if release.get("prerelease") is False:
        checks.append(pass_check("github-release:prerelease", "false"))
    else:
        checks.append(
            fail_check("github-release:prerelease", f"expected false, got {release.get('prerelease')!r}")
        )

    assets = index_assets(release)
    expected_names = expected_asset_names(version)
    checks.extend(check_unexpected_assets(release, expected_names=expected_names))
    for name in sorted(expected_names):
        asset = assets.get(name)
        if not asset:
            checks.append(fail_check(f"github-asset:{name}", "missing"))
            continue
        download_url = asset_download_url(asset)
        if download_url:
            checks.append(pass_check(f"github-asset:{name}", download_url))
        else:
            checks.append(fail_check(f"github-asset:{name}", "missing browser_download_url"))
        state = asset.get("state")
        if state == "uploaded":
            checks.append(pass_check(f"github-asset-state:{name}", "uploaded"))
        else:
            checks.append(fail_check(f"github-asset-state:{name}", f"expected uploaded, got {state!r}"))
        size = asset.get("size")
        if isinstance(size, int) and size > 0:
            checks.append(pass_check(f"github-asset-size:{name}", str(size)))
        else:
            checks.append(fail_check(f"github-asset-size:{name}", f"expected positive integer, got {size!r}"))
        if download_url.startswith(download_url_prefix):
            checks.append(pass_check(f"github-asset-url:{name}", "uses expected download URL"))
        elif download_url:
            checks.append(
                fail_check(
                    f"github-asset-url:{name}",
                    f"expected prefix {download_url_prefix}, got {download_url}",
                )
            )
    return assets, checks


def normalize_release_notes(text: str) -> str:
    return text.replace("\r\n", "\n").strip()


def check_release_notes_quality(notes_path: Path, version: str) -> list[Check]:
    script_path = Path(__file__).with_name("verify_release_notes.py")
    result = subprocess.run(
        [
            sys.executable,
            str(script_path),
            "--notes-file",
            str(notes_path),
            "--version",
            version,
            "--quiet",
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
        check=False,
    )
    if result.returncode == 0:
        return [pass_check("release-notes:quality", "verified")]
    detail = (result.stdout or result.stderr).strip()
    return [fail_check("release-notes:quality", detail or f"exited {result.returncode}")]


def check_release_notes(release: dict[str, Any], notes_path: Path, version: str) -> list[Check]:
    if not notes_path.exists():
        return [fail_check("github-release:body", f"release notes file not found: {notes_path}")]

    checks = check_release_notes_quality(notes_path, version)
    expected = normalize_release_notes(notes_path.read_text())
    actual_value = release.get("body", "")
    actual = normalize_release_notes(actual_value if isinstance(actual_value, str) else "")
    if actual == expected:
        checks.append(pass_check("github-release:body", "matches release notes file"))
    else:
        checks.append(fail_check("github-release:body", "does not match release notes file"))
    return checks


def check_manifest(
    manifest: dict[str, Any],
    *,
    version: str,
    tag: str,
) -> tuple[dict[str, str], str, list[Check]]:
    checks: list[Check] = []
    if manifest.get("app") == APP_NAME:
        checks.append(pass_check("manifest:app", APP_NAME))
    else:
        checks.append(fail_check("manifest:app", f"expected {APP_NAME}, got {manifest.get('app')!r}"))
    if manifest.get("kind") == "public-release":
        checks.append(pass_check("manifest:kind", "public-release"))
    else:
        checks.append(
            fail_check("manifest:kind", f"expected 'public-release', got {manifest.get('kind')!r}")
        )
    if manifest.get("version") == version:
        checks.append(pass_check("manifest:version", version))
    else:
        checks.append(fail_check("manifest:version", f"expected {version}, got {manifest.get('version')!r}"))
    build = str(manifest.get("build", ""))
    if validate_build(build):
        checks.append(pass_check("manifest:build", build))
    else:
        checks.append(fail_check("manifest:build", f"expected positive integer string, got {build!r}"))
    if manifest.get("tag") == tag:
        checks.append(pass_check("manifest:tag", tag))
    else:
        checks.append(fail_check("manifest:tag", f"expected {tag}, got {manifest.get('tag')!r}"))
    if manifest.get("public_release") is True:
        checks.append(pass_check("manifest:public_release", "true"))
    else:
        checks.append(
            fail_check("manifest:public_release", f"expected true, got {manifest.get('public_release')!r}")
        )
    if manifest.get("notarized") is True:
        checks.append(pass_check("manifest:notarized", "true"))
    else:
        checks.append(fail_check("manifest:notarized", f"expected true, got {manifest.get('notarized')!r}"))

    artifact_shas: dict[str, str] = {}
    for key, expected_name in (
        ("dmg", f"{APP_NAME}-{version}.dmg"),
        ("zip", f"{APP_NAME}-{version}.zip"),
    ):
        value = manifest.get(key)
        if not isinstance(value, dict):
            checks.append(fail_check(f"manifest:{key}", "missing object"))
            continue
        raw_path = str(value.get("path", ""))
        name = Path(raw_path).name
        sha256 = str(value.get("sha256", "")).lower()
        if raw_path == expected_name:
            checks.append(pass_check(f"manifest:{key}.path", expected_name))
        else:
            checks.append(
                fail_check(
                    f"manifest:{key}.path",
                    f"expected artifact filename {expected_name}, got {raw_path!r}",
                )
            )
        if validate_sha256(sha256):
            checks.append(pass_check(f"manifest:{key}.sha256", sha256))
            artifact_shas[expected_name] = sha256
        else:
            checks.append(fail_check(f"manifest:{key}.sha256", f"invalid sha256 {sha256!r}"))
    return artifact_shas, build if validate_build(build) else "", checks


def check_sha256s(
    sha256s_text: str,
    *,
    artifact_shas: dict[str, str],
) -> list[Check]:
    checks: list[Check] = []
    entries = parse_sha256s(sha256s_text)
    for name, expected_sha in artifact_shas.items():
        actual_sha, raw_path = entries.get(name, ("", ""))
        if raw_path and raw_path != name:
            checks.append(
                fail_check(
                    f"sha256s-path:{name}",
                    f"expected artifact filename {name}, got {raw_path!r}",
                )
            )
        if actual_sha == expected_sha:
            checks.append(pass_check(f"sha256s:{name}", expected_sha))
        else:
            checks.append(fail_check(f"sha256s:{name}", f"expected {expected_sha}, got {actual_sha!r}"))
    return checks


def check_appcast(
    xml_text: str,
    *,
    expected_dmg_url: str,
    expected_dmg_size: int | None,
    expected_version: str,
    expected_build: str,
    name: str,
) -> list[Check]:
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as error:
        return [fail_check(name, f"invalid XML: {error}")]

    checks: list[Check] = [pass_check(name, "valid XML")]
    enclosure = None
    item = None
    urls: list[str] = []
    for candidate_item in root.iter("item"):
        for candidate in candidate_item.iter("enclosure"):
            candidate_url = candidate.attrib.get("url", "")
            urls.append(candidate_url)
            if candidate_url == expected_dmg_url:
                item = candidate_item
                enclosure = candidate
                break
        if enclosure is not None:
            break
    if enclosure is None:
        return checks + [fail_check(f"{name}:enclosure-url", f"expected {expected_dmg_url}, got {urls}")]
    checks.append(pass_check(f"{name}:enclosure-url", expected_dmg_url))

    signature = enclosure.attrib.get(f"{{{SPARKLE_NS}}}edSignature", "")
    if signature:
        checks.append(pass_check(f"{name}:edSignature", "present"))
    else:
        checks.append(fail_check(f"{name}:edSignature", "missing"))

    if expected_build:
        actual_build = sparkle_item_value(item, enclosure, "version")
        if actual_build == expected_build:
            checks.append(pass_check(f"{name}:version", expected_build))
        else:
            checks.append(fail_check(f"{name}:version", f"expected {expected_build}, got {actual_build!r}"))

    actual_short_version = sparkle_item_value(item, enclosure, "shortVersionString")
    if actual_short_version == expected_version:
        checks.append(pass_check(f"{name}:shortVersionString", expected_version))
    else:
        checks.append(
            fail_check(
                f"{name}:shortVersionString",
                f"expected {expected_version}, got {actual_short_version!r}",
            )
        )

    if expected_dmg_size is not None:
        actual_length = enclosure.attrib.get("length", "")
        if actual_length == str(expected_dmg_size):
            checks.append(pass_check(f"{name}:length", actual_length))
        else:
            checks.append(fail_check(f"{name}:length", f"expected {expected_dmg_size}, got {actual_length!r}"))
    return checks


def appcast_release_notes_links(xml_text: str, *, expected_dmg_url: str) -> list[str]:
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return []

    for candidate_item in root.iter("item"):
        for candidate in candidate_item.iter("enclosure"):
            if candidate.attrib.get("url", "") == expected_dmg_url:
                links: list[str] = []
                for child in candidate_item.findall(f"{{{SPARKLE_NS}}}releaseNotesLink"):
                    if child.text and child.text.strip():
                        links.append(child.text.strip())
                return links
    return []


def check_appcast_release_notes_link(
    xml_text: str,
    *,
    expected_dmg_url: str,
    expected_notes_text: str,
    timeout: int,
    name: str,
) -> list[Check]:
    links = appcast_release_notes_links(xml_text, expected_dmg_url=expected_dmg_url)
    if not links:
        return [warn_check(f"{name}:releaseNotesLink", "missing")]

    checks: list[Check] = []
    for index, link in enumerate(links, start=1):
        check_name = f"{name}:releaseNotesLink:{index}"
        try:
            actual_notes = fetch_bytes(link, timeout=timeout).decode("utf-8")
        except (OSError, UnicodeDecodeError, urllib.error.URLError) as error:
            checks.append(fail_check(check_name, f"{link}: {error}"))
            continue

        if normalize_release_notes(actual_notes) == expected_notes_text:
            checks.append(pass_check(check_name, link))
        else:
            checks.append(fail_check(check_name, f"{link}: content does not match release notes file"))
    return checks


def sparkle_item_value(item: ET.Element | None, enclosure: ET.Element, name: str) -> str:
    namespaced_name = f"{{{SPARKLE_NS}}}{name}"
    if item is not None:
        child = item.find(namespaced_name)
        if child is not None and child.text:
            return child.text.strip()
    return enclosure.attrib.get(namespaced_name, "")


def check_published_appcast_matches_release_asset(release_appcast: str, published_appcast: str) -> Check:
    release_sha = hashlib.sha256(release_appcast.encode("utf-8")).hexdigest()
    published_sha = hashlib.sha256(published_appcast.encode("utf-8")).hexdigest()
    if published_sha == release_sha:
        return pass_check("published-appcast:release-asset-match", published_sha)
    return fail_check(
        "published-appcast:release-asset-match",
        f"expected release appcast sha256 {release_sha}, got {published_sha}",
    )


def fetch_text_asset(
    assets: dict[str, dict[str, Any]],
    name: str,
    *,
    timeout: int,
    token: str,
) -> tuple[str | None, list[Check]]:
    asset = assets.get(name)
    if not asset:
        return None, [fail_check(f"download:{name}", "asset missing")]
    url = asset_download_url(asset)
    if not url:
        return None, [fail_check(f"download:{name}", "asset URL missing")]
    try:
        text = fetch_bytes(url, timeout=timeout, token=token).decode("utf-8")
    except (OSError, UnicodeDecodeError, urllib.error.URLError) as error:
        return None, [fail_check(f"download:{name}", str(error))]
    return text, [pass_check(f"download:{name}", url)]


def run_downloaded_dmg_check(*, name: str, command: list[str], timeout: int) -> Check:
    try:
        result = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return fail_check(name, f"timed out after {timeout}s")

    detail = (result.stdout or result.stderr).strip().splitlines()
    message = detail[-1] if detail else f"exited {result.returncode}"
    if result.returncode == 0:
        return pass_check(name, message)
    return fail_check(name, message)


def check_downloaded_dmg_install(*, dmg_path: Path, timeout: int) -> list[Check]:
    script_dir = Path(__file__).parent
    return [
        run_downloaded_dmg_check(
            name="published-dmg:layout",
            command=[
                str(script_dir / "verify_dmg_layout.sh"),
                "--dmg",
                str(dmg_path),
                "--timeout",
                str(timeout),
            ],
            timeout=timeout,
        ),
        run_downloaded_dmg_check(
            name="published-dmg:install",
            command=[
                str(script_dir / "verify_dmg_install.sh"),
                "--dmg",
                str(dmg_path),
                "--timeout",
                str(timeout),
            ],
            timeout=timeout,
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--version", default="")
    parser.add_argument("--tag", default="")
    parser.add_argument("--appcast-url", default=os.environ.get("HOLDTYPE_UPDATE_FEED_URL", ""))
    parser.add_argument("--github-api-url", default=os.environ.get("GITHUB_API_URL", "https://api.github.com"))
    parser.add_argument("--download-url-prefix", default="")
    parser.add_argument("--github-token-env", default="GITHUB_TOKEN")
    parser.add_argument("--release-notes-file", default="")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--download-dmg", action="store_true")
    parser.add_argument(
        "--verify-downloaded-dmg-install",
        action="store_true",
        help="after downloading the public DMG, mount it and verify the copy/install path",
    )
    parser.add_argument("--download-dir", default="")
    args = parser.parse_args()

    checks: list[Check] = []
    repository = args.repository
    tag = args.tag
    version = args.version
    if version and version.startswith("v"):
        checks.append(fail_check("version", "must not include leading v"))
    if not tag and version:
        tag = f"v{version}"
    if tag and not version:
        version = tag[1:] if tag.startswith("v") else tag
    if not repository:
        checks.append(fail_check("repository", "missing --repository or GITHUB_REPOSITORY"))
    elif not validate_repository_slug(repository):
        checks.append(fail_check("repository", f"expected OWNER/REPO, got {repository!r}"))
    if not tag:
        checks.append(fail_check("tag", "missing --tag or --version"))
    if not version:
        checks.append(fail_check("version", "missing --version or --tag"))
    if checks:
        print_checks(checks)
        return 1

    token = os.environ.get(args.github_token_env, "")
    url = release_api_url(args.github_api_url, repository, tag)
    try:
        release = fetch_json(url, timeout=args.timeout, token=token)
    except (OSError, json.JSONDecodeError, urllib.error.URLError) as error:
        print_checks([fail_check("github-release", f"{url}: {error}")])
        return 1
    if not isinstance(release, dict):
        print_checks([fail_check("github-release", "API response is not an object")])
        return 1

    download_url_prefix = args.download_url_prefix or (
        f"https://github.com/{repository}/releases/download/{tag}/"
    )
    download_url_prefix = f"{download_url_prefix.rstrip('/')}/"

    assets, release_checks = check_release_basics(
        release,
        download_url_prefix=download_url_prefix,
        tag=tag,
        version=version,
    )
    checks.extend(release_checks)

    expected_notes_text = ""
    if args.release_notes_file:
        release_notes_path = Path(args.release_notes_file)
        checks.extend(check_release_notes(release, release_notes_path, version))
        if release_notes_path.exists():
            expected_notes_text = normalize_release_notes(release_notes_path.read_text())

    manifest_text, manifest_checks = fetch_text_asset(
        assets,
        "release-manifest.json",
        timeout=args.timeout,
        token=token,
    )
    checks.extend(manifest_checks)
    artifact_shas: dict[str, str] = {}
    manifest_build = ""
    if manifest_text is not None:
        try:
            manifest = json.loads(manifest_text)
        except json.JSONDecodeError as error:
            checks.append(fail_check("manifest", f"invalid JSON: {error}"))
        else:
            artifact_shas, manifest_build, manifest_inner_checks = check_manifest(
                manifest,
                version=version,
                tag=tag,
            )
            checks.extend(manifest_inner_checks)

    sha256s_text, sha256s_checks = fetch_text_asset(
        assets,
        "SHA256SUMS.txt",
        timeout=args.timeout,
        token=token,
    )
    checks.extend(sha256s_checks)
    if sha256s_text is not None and artifact_shas:
        checks.extend(check_sha256s(sha256s_text, artifact_shas=artifact_shas))

    dmg_name = f"{APP_NAME}-{version}.dmg"
    dmg_asset = assets.get(dmg_name, {})
    dmg_url = asset_download_url(dmg_asset)
    dmg_size_raw = dmg_asset.get("size")
    dmg_size = dmg_size_raw if isinstance(dmg_size_raw, int) else None
    expected_dmg_url = f"{download_url_prefix}{dmg_name}"
    if dmg_url == expected_dmg_url:
        checks.append(pass_check("published-dmg:url", expected_dmg_url))
    elif dmg_url:
        checks.append(fail_check("published-dmg:url", f"expected {expected_dmg_url}, got {dmg_url}"))

    appcast_text, appcast_checks = fetch_text_asset(
        assets,
        "appcast.xml",
        timeout=args.timeout,
        token=token,
    )
    checks.extend(appcast_checks)
    if appcast_text is not None:
        checks.extend(
            check_appcast(
                appcast_text,
                expected_dmg_url=expected_dmg_url,
                expected_dmg_size=dmg_size,
                expected_version=version,
                expected_build=manifest_build,
                name="release-appcast",
            )
        )

    if args.appcast_url:
        try:
            published_appcast = fetch_bytes(args.appcast_url, timeout=args.timeout).decode("utf-8")
        except (OSError, UnicodeDecodeError, urllib.error.URLError) as error:
            checks.append(fail_check("published-appcast", f"{args.appcast_url}: {error}"))
        else:
            checks.append(pass_check("published-appcast:url", args.appcast_url))
            if appcast_text is not None:
                checks.append(
                    check_published_appcast_matches_release_asset(appcast_text, published_appcast)
                )
            checks.extend(
                check_appcast(
                    published_appcast,
                    expected_dmg_url=expected_dmg_url,
                    expected_dmg_size=dmg_size,
                    expected_version=version,
                    expected_build=manifest_build,
                    name="published-appcast",
                )
            )
            if expected_notes_text:
                checks.extend(
                    check_appcast_release_notes_link(
                        published_appcast,
                        expected_dmg_url=expected_dmg_url,
                        expected_notes_text=expected_notes_text,
                        timeout=args.timeout,
                        name="published-appcast",
                    )
                )
    else:
        checks.append(warn_check("published-appcast", "missing --appcast-url or HOLDTYPE_UPDATE_FEED_URL"))

    if (args.download_dmg or args.verify_downloaded_dmg_install) and artifact_shas:
        expected_sha = artifact_shas.get(dmg_name, "")
        download_dir = Path(args.download_dir) if args.download_dir else Path(tempfile.mkdtemp())
        download_dir.mkdir(parents=True, exist_ok=True)
        output_path = download_dir / dmg_name
        try:
            actual_sha = download_sha256(dmg_url, timeout=args.timeout, token=token, output_path=output_path)
        except (OSError, urllib.error.URLError) as error:
            checks.append(fail_check("published-dmg:sha256", str(error)))
        else:
            if actual_sha == expected_sha:
                checks.append(pass_check("published-dmg:sha256", actual_sha))
            else:
                checks.append(fail_check("published-dmg:sha256", f"expected {expected_sha}, got {actual_sha}"))
            checks.append(pass_check("published-dmg:download", str(output_path)))
            if args.verify_downloaded_dmg_install and actual_sha == expected_sha:
                checks.extend(check_downloaded_dmg_install(dmg_path=output_path, timeout=args.timeout))

    print_checks(checks)
    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
