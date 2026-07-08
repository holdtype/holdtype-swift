#!/usr/bin/env python3
"""Verify Sparkle update settings embedded in a built HoldType.app."""

from __future__ import annotations

import argparse
import plistlib
import sys
from dataclasses import dataclass
from pathlib import Path


SPARKLE_KEYS = ("SUFeedURL", "SUPublicEDKey")


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def print_checks(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def read_info_plist(app_path: Path) -> tuple[dict[str, object] | None, list[Check]]:
    info_plist_path = app_path / "Contents" / "Info.plist"
    if not app_path.exists():
        return None, [fail_check("app", f"missing {app_path}")]
    if not info_plist_path.exists():
        return None, [fail_check("info-plist", f"missing {info_plist_path}")]

    try:
        with info_plist_path.open("rb") as handle:
            return plistlib.load(handle), [pass_check("info-plist", str(info_plist_path))]
    except Exception as error:  # noqa: BLE001 - release verifier should surface parse failures
        return None, [fail_check("info-plist", f"could not parse plist: {error}")]


def is_configured_value(value: object) -> bool:
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    return bool(stripped) and "$(" not in stripped


def check_exact_value(plist: dict[str, object], key: str, expected: str) -> Check:
    actual = plist.get(key)
    if actual == expected:
        return pass_check(f"info-plist:{key}", "matches expected release value")
    return fail_check(f"info-plist:{key}", f"expected {expected!r}, got {actual!r}")


def check_configured_value(plist: dict[str, object], key: str) -> Check:
    actual = plist.get(key)
    if is_configured_value(actual):
        return pass_check(f"info-plist:{key}", "configured")
    return fail_check(f"info-plist:{key}", f"not configured: {actual!r}")


def check_unconfigured_allowed(plist: dict[str, object], key: str) -> Check:
    if key in plist:
        return pass_check(f"info-plist:{key}", "present")
    return fail_check(f"info-plist:{key}", "missing")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, help="Path to HoldType.app")
    parser.add_argument("--expected-feed-url", default="")
    parser.add_argument("--expected-public-ed-key", default="")
    parser.add_argument(
        "--require-configured",
        action="store_true",
        help="Require non-empty Sparkle settings when exact values are not provided.",
    )
    parser.add_argument(
        "--allow-unconfigured",
        action="store_true",
        help="Only require Sparkle keys to exist. Intended for local preview builds.",
    )
    args = parser.parse_args()

    if args.allow_unconfigured and args.require_configured:
        print("[fail] arguments: choose either --allow-unconfigured or --require-configured", file=sys.stderr)
        return 1

    expected_values = {
        "SUFeedURL": args.expected_feed_url,
        "SUPublicEDKey": args.expected_public_ed_key,
    }
    has_any_expected = any(expected_values.values())
    has_all_expected = all(expected_values.values())
    if has_any_expected and not has_all_expected:
        print("[fail] arguments: expected feed URL and public EdDSA key must be provided together", file=sys.stderr)
        return 1
    if not has_all_expected and not args.require_configured and not args.allow_unconfigured:
        print(
            "[fail] arguments: provide exact expected values, --require-configured, or --allow-unconfigured",
            file=sys.stderr,
        )
        return 1

    plist, checks = read_info_plist(Path(args.app))
    if plist is None:
        print_checks(checks)
        return 1

    if has_all_expected:
        for key in SPARKLE_KEYS:
            checks.append(check_exact_value(plist, key, expected_values[key]))
    elif args.require_configured:
        for key in SPARKLE_KEYS:
            checks.append(check_configured_value(plist, key))
    else:
        for key in SPARKLE_KEYS:
            checks.append(check_unconfigured_allowed(plist, key))

    print_checks(checks)
    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
