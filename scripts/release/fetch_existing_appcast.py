#!/usr/bin/env python3
"""Fetch an existing Sparkle appcast if it is already published."""

from __future__ import annotations

import argparse
import sys
import urllib.error
import urllib.request
from pathlib import Path


def log(message: str) -> None:
    print(f"[release] {message}")


def warn(message: str) -> None:
    print(f"[release:warn] {message}", file=sys.stderr)


def fail(message: str) -> int:
    print(f"[release:error] {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(
        args.url,
        headers={"User-Agent": "holdtype-release-appcast-fetcher"},
    )
    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            warn(f"existing appcast not found: {args.url}")
            return 0
        return fail(f"could not fetch existing appcast: HTTP {error.code} {args.url}")
    except OSError as error:
        return fail(f"could not fetch existing appcast: {error}")

    output_path.write_bytes(body)
    log(f"existing appcast ready: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
