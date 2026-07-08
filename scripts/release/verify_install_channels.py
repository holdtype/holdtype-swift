#!/usr/bin/env python3
"""Verify release metadata for Sparkle and Homebrew install channels."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


APP_NAME = "HoldType"
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
BUILD_PATTERN = re.compile(r"^[0-9]+$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def print_checks(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


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

    candidates = [
        Path.cwd() / path,
        repo_root() / path,
        release_dir / path,
        release_dir / path.name,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return repo_root() / path


def is_artifact_filename(raw_path: str) -> bool:
    path = Path(raw_path)
    return bool(raw_path) and not path.is_absolute() and path.name == raw_path


def validate_sha256(value: str) -> bool:
    return bool(SHA256_PATTERN.fullmatch(value.lower()))


def validate_build(value: str) -> bool:
    return bool(BUILD_PATTERN.fullmatch(value) and int(value) > 0)


def load_manifest(release_dir: Path) -> tuple[dict[str, object] | None, list[Check]]:
    path = release_dir / "release-manifest.json"
    if not path.exists():
        return None, [fail_check("manifest", f"missing {path}")]

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        return None, [fail_check("manifest", f"invalid JSON: {error}")]

    checks = [pass_check("manifest", str(path))]
    return data, checks


def check_release_contract(manifest: dict[str, object]) -> list[Check]:
    checks: list[Check] = []
    if manifest.get("app") == APP_NAME:
        checks.append(pass_check("manifest:app", APP_NAME))
    else:
        checks.append(fail_check("manifest:app", f"expected {APP_NAME}, got {manifest.get('app')!r}"))

    if manifest.get("kind") == "public-release":
        checks.append(pass_check("manifest:kind", "public-release"))
    else:
        checks.append(
            fail_check("manifest:kind", f"expected public-release, got {manifest.get('kind')!r}")
        )

    if manifest.get("public_release") is True:
        checks.append(pass_check("manifest:public_release", "true"))
    else:
        checks.append(
            fail_check(
                "manifest:public_release",
                f"expected true, got {manifest.get('public_release')!r}",
            )
        )

    if manifest.get("notarized") is True:
        checks.append(pass_check("manifest:notarized", "true"))
    else:
        checks.append(
            fail_check(
                "manifest:notarized",
                f"expected true, got {manifest.get('notarized')!r}",
            )
        )
    return checks


def check_manifest_artifact(
    *,
    release_dir: Path,
    manifest: dict[str, object],
    version: str,
    key: str,
    extension: str,
) -> tuple[dict[str, str], list[Check]]:
    checks: list[Check] = []
    value = manifest.get(key)
    if not isinstance(value, dict):
        checks.append(fail_check(f"manifest:{key}", "missing object"))
        return {"path": "", "sha256": ""}, checks

    raw_path = str(value.get("path", ""))
    expected_sha = str(value.get("sha256", "")).lower()
    if not raw_path:
        checks.append(fail_check(f"manifest:{key}.path", "missing"))
        return {"path": "", "sha256": expected_sha}, checks

    expected_name = f"{APP_NAME}-{version}.{extension}"
    if raw_path == expected_name:
        checks.append(pass_check(f"manifest:{key}.path", expected_name))
    elif is_artifact_filename(raw_path):
        checks.append(fail_check(f"manifest:{key}.path", f"expected {expected_name}, got {raw_path!r}"))
    else:
        checks.append(
            fail_check(
                f"manifest:{key}.path",
                f"expected artifact filename {expected_name}, got {raw_path!r}",
            )
        )

    artifact_path = resolve_artifact_path(raw_path, release_dir)
    if artifact_path.name == expected_name:
        checks.append(pass_check(f"{key}:name", expected_name))
    else:
        checks.append(fail_check(f"{key}:name", f"expected {expected_name}, got {artifact_path.name}"))

    if artifact_path.exists():
        checks.append(pass_check(f"{key}:file", str(artifact_path)))
    else:
        checks.append(fail_check(f"{key}:file", f"missing {artifact_path}"))
        return {"path": str(artifact_path), "sha256": expected_sha}, checks

    if not validate_sha256(expected_sha):
        checks.append(fail_check(f"manifest:{key}.sha256", f"invalid sha256 {expected_sha!r}"))
        return {"path": str(artifact_path), "sha256": expected_sha}, checks

    actual_sha = sha256_for_file(artifact_path)
    if actual_sha == expected_sha:
        checks.append(pass_check(f"{key}:sha256", actual_sha))
    else:
        checks.append(fail_check(f"{key}:sha256", f"expected {expected_sha}, got {actual_sha}"))
    return {"path": str(artifact_path), "sha256": actual_sha}, checks


def check_manifest_and_artifacts(
    release_dir: Path,
    manifest: dict[str, object],
) -> tuple[dict[str, str], list[Check]]:
    checks: list[Check] = []
    version = str(manifest.get("version", ""))
    build = str(manifest.get("build", ""))
    tag = str(manifest.get("tag", ""))
    if not version:
        checks.append(fail_check("manifest:version", "missing"))
    if validate_build(build):
        checks.append(pass_check("manifest:build", build))
    else:
        checks.append(fail_check("manifest:build", f"expected positive integer string, got {build!r}"))
    if tag != f"v{version}":
        checks.append(fail_check("manifest:tag", f"expected v{version}, got {tag!r}"))

    checks.extend(check_release_contract(manifest))
    dmg_artifact, dmg_checks = check_manifest_artifact(
        release_dir=release_dir,
        manifest=manifest,
        version=version,
        key="dmg",
        extension="dmg",
    )
    checks.extend(dmg_checks)
    zip_artifact, zip_checks = check_manifest_artifact(
        release_dir=release_dir,
        manifest=manifest,
        version=version,
        key="zip",
        extension="zip",
    )
    checks.extend(zip_checks)

    return {
        "version": version,
        "build": build,
        "tag": tag,
        "dmg_path": dmg_artifact["path"],
        "dmg_sha256": dmg_artifact["sha256"],
        "zip_path": zip_artifact["path"],
        "zip_sha256": zip_artifact["sha256"],
    }, checks


def check_sha256s(release_dir: Path) -> list[Check]:
    path = release_dir / "SHA256SUMS.txt"
    if not path.exists():
        return [fail_check("sha256s", f"missing {path}")]

    checks: list[Check] = []
    failed = False
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2:
            checks.append(fail_check("sha256s", f"malformed line: {line}"))
            failed = True
            continue
        expected_sha, raw_file = parts
        raw_file = raw_file.strip()
        if not is_artifact_filename(raw_file):
            checks.append(fail_check("sha256s:path", f"expected artifact filename, got {raw_file!r}"))
            failed = True
        artifact_path = resolve_artifact_path(raw_file, release_dir)
        if not artifact_path.exists():
            checks.append(fail_check("sha256s", f"missing artifact {artifact_path}"))
            failed = True
            continue
        actual_sha = sha256_for_file(artifact_path)
        if actual_sha != expected_sha.lower():
            checks.append(
                fail_check("sha256s", f"{artifact_path.name}: expected {expected_sha}, got {actual_sha}")
            )
            failed = True

    if not failed:
        checks.append(pass_check("sha256s", "all listed artifacts match"))
    return checks


def check_appcast(
    release_dir: Path,
    *,
    expected_url: str,
    expected_version: str,
    expected_build: str,
    dmg_path: Path,
) -> list[Check]:
    path = release_dir / "appcast.xml"
    if not path.exists():
        return [fail_check("appcast", f"missing {path}")]

    try:
        root = ET.fromstring(path.read_text())
    except ET.ParseError as error:
        return [fail_check("appcast", f"invalid XML: {error}")]

    checks: list[Check] = [pass_check("appcast", str(path))]
    enclosure = None
    item = None
    urls: list[str] = []
    for candidate_item in root.iter("item"):
        for candidate in candidate_item.iter("enclosure"):
            candidate_url = candidate.attrib.get("url", "")
            urls.append(candidate_url)
            if candidate_url == expected_url:
                item = candidate_item
                enclosure = candidate
                break
        if enclosure is not None:
            break

    if enclosure is None:
        return checks + [fail_check("appcast:enclosure-url", f"expected {expected_url}, got {urls}")]

    checks.append(pass_check("appcast:enclosure-url", expected_url))

    signature = enclosure.attrib.get(f"{{{SPARKLE_NS}}}edSignature", "")
    if signature:
        checks.append(pass_check("appcast:edSignature", "present"))
    else:
        checks.append(fail_check("appcast:edSignature", "missing"))

    actual_build = sparkle_item_value(item, enclosure, "version")
    if actual_build == expected_build:
        checks.append(pass_check("appcast:version", expected_build))
    else:
        checks.append(fail_check("appcast:version", f"expected {expected_build}, got {actual_build!r}"))

    actual_short_version = sparkle_item_value(item, enclosure, "shortVersionString")
    if actual_short_version == expected_version:
        checks.append(pass_check("appcast:shortVersionString", expected_version))
    else:
        checks.append(
            fail_check(
                "appcast:shortVersionString",
                f"expected {expected_version}, got {actual_short_version!r}",
            )
        )

    expected_length = str(dmg_path.stat().st_size)
    actual_length = enclosure.attrib.get("length", "")
    if actual_length == expected_length:
        checks.append(pass_check("appcast:length", expected_length))
    else:
        checks.append(fail_check("appcast:length", f"expected {expected_length}, got {actual_length!r}"))

    return checks


def sparkle_item_value(item: ET.Element | None, enclosure: ET.Element, name: str) -> str:
    namespaced_name = f"{{{SPARKLE_NS}}}{name}"
    if item is not None:
        child = item.find(namespaced_name)
        if child is not None and child.text:
            return child.text.strip()
    return enclosure.attrib.get(namespaced_name, "")


def render_homebrew_cask(
    *,
    version: str,
    sha256: str,
    repository: str,
    minimum_macos: str,
    keep_temp: bool,
) -> tuple[Path, Path | None]:
    temp_dir = Path(tempfile.mkdtemp(prefix="holdtype-cask-"))
    output_path = temp_dir / "Casks" / "holdtype.rb"
    command = [
        str(repo_root() / "scripts" / "release" / "render_homebrew_cask.sh"),
        "--version",
        version,
        "--sha256",
        sha256,
        "--repository",
        repository,
        "--output",
        str(output_path),
    ]
    if minimum_macos:
        command.extend(["--minimum-macos", minimum_macos])

    subprocess.run(
        command,
        cwd=repo_root(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return output_path, temp_dir if keep_temp else None


def check_homebrew_cask(
    *,
    version: str,
    sha256: str,
    repository: str,
    minimum_macos: str,
    keep_temp: bool,
) -> list[Check]:
    temp_dir_to_keep: Path | None = None
    temp_root: Path | None = None
    try:
        output_path, temp_dir_to_keep = render_homebrew_cask(
            version=version,
            sha256=sha256,
            repository=repository,
            minimum_macos=minimum_macos,
            keep_temp=keep_temp,
        )
        temp_root = output_path.parents[1]
        text = output_path.read_text()
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or str(error)).strip()
        return [fail_check("homebrew-cask", detail)]

    checks: list[Check] = [pass_check("homebrew-cask:render", str(output_path))]
    expected_fragments = {
        "homebrew-cask:version": f'version "{version}"',
        "homebrew-cask:sha256": f'sha256 "{sha256}"',
        "homebrew-cask:url": (
            f"https://github.com/{repository}/releases/download/v#{{version}}/"
            f"{APP_NAME}-#{{version}}.dmg"
        ),
        "homebrew-cask:auto-updates": "auto_updates true",
        "homebrew-cask:app": f'app "{APP_NAME}.app"',
        "homebrew-cask:uninstall-quit": 'uninstall quit: "app.holdtype.HoldType"',
        "homebrew-cask:zap": "zap trash: [",
        "homebrew-cask:zap-caches": '"~/Library/Caches/HoldType"',
        "homebrew-cask:zap-preferences": '"~/Library/Preferences/app.holdtype.HoldType.plist"',
        "homebrew-cask:zap-saved-state": '"~/Library/Saved Application State/app.holdtype.HoldType.savedState"',
    }
    for name, fragment in expected_fragments.items():
        if fragment in text:
            checks.append(pass_check(name, "present"))
        else:
            checks.append(fail_check(name, f"missing {fragment!r}"))

    if minimum_macos:
        fragment = f'depends_on macos: "{minimum_macos}"'
        if fragment in text:
            checks.append(pass_check("homebrew-cask:minimum-macos", minimum_macos))
        else:
            checks.append(fail_check("homebrew-cask:minimum-macos", f"missing {fragment!r}"))

    if temp_dir_to_keep is not None:
        checks.append(pass_check("homebrew-cask:temp", str(temp_dir_to_keep)))
    elif temp_root is not None:
        shutil.rmtree(temp_root, ignore_errors=True)
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-dir", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--download-url-prefix", default="")
    parser.add_argument("--minimum-macos", default=os.environ.get("HOMEBREW_MINIMUM_MACOS", ""))
    parser.add_argument("--keep-temp", action="store_true")
    args = parser.parse_args()

    release_dir = Path(args.release_dir).resolve()
    checks: list[Check] = []

    if not args.repository:
        checks.append(fail_check("repository", "missing --repository or GITHUB_REPOSITORY"))
        print_checks(checks)
        return 1

    manifest, manifest_checks = load_manifest(release_dir)
    checks.extend(manifest_checks)
    if manifest is None:
        print_checks(checks)
        return 1

    artifacts, artifact_checks = check_manifest_and_artifacts(release_dir, manifest)
    checks.extend(artifact_checks)
    checks.extend(check_sha256s(release_dir))

    version = artifacts["version"]
    tag = artifacts["tag"]
    dmg_path = Path(artifacts["dmg_path"])
    dmg_sha256 = artifacts["dmg_sha256"]
    download_url_prefix = args.download_url_prefix or (
        f"https://github.com/{args.repository}/releases/download/{tag}/"
    )
    expected_url = f"{download_url_prefix.rstrip('/')}/{dmg_path.name}"

    if version and tag and dmg_path.exists():
        checks.extend(
            check_appcast(
                release_dir,
                expected_url=expected_url,
                expected_version=version,
                expected_build=artifacts["build"],
                dmg_path=dmg_path,
            )
        )
    if version and dmg_sha256:
        checks.extend(
            check_homebrew_cask(
                version=version,
                sha256=dmg_sha256,
                repository=args.repository,
                minimum_macos=args.minimum_macos,
                keep_temp=args.keep_temp,
            )
        )

    print_checks(checks)
    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
