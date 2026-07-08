#!/usr/bin/env python3
"""Regenerate AppIcon.appiconset PNGs from one square source image."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_APPICONSET = REPO_ROOT / "HoldType/Assets.xcassets/AppIcon.appiconset"
DEFAULT_SOURCE = (
    REPO_ROOT
    / "HoldType/Assets.xcassets/AppIcon.appiconset_not_cropped"
    / "AppIconDay-ios-marketing-1024x1024@1x-crop.png"
)
DEFAULT_SIPS = Path("/usr/bin/sips")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Resize one square PNG into every filename declared by an "
            "AppIcon.appiconset Contents.json."
        )
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Square source PNG. Default: {DEFAULT_SOURCE.relative_to(REPO_ROOT)}",
    )
    parser.add_argument(
        "--appiconset",
        type=Path,
        default=DEFAULT_APPICONSET,
        help=f"Target .appiconset directory. Default: {DEFAULT_APPICONSET.relative_to(REPO_ROOT)}",
    )
    parser.add_argument(
        "--sips",
        type=Path,
        default=DEFAULT_SIPS,
        help=f"sips executable path. Default: {DEFAULT_SIPS}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned outputs without writing files.",
    )
    return parser.parse_args()


def resolve(path: Path) -> Path:
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def image_dimensions(path: Path, sips: Path) -> tuple[int, int]:
    result = subprocess.run(
        [str(sips), "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    width: int | None = None
    height: int | None = None
    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if line.startswith("pixelWidth:"):
            width = int(line.split(":", 1)[1].strip())
        elif line.startswith("pixelHeight:"):
            height = int(line.split(":", 1)[1].strip())
    if width is None or height is None:
        raise ValueError(f"Could not read pixel dimensions for {path}")
    return width, height


def target_pixels(image: dict[str, str]) -> int:
    size = Decimal(image["size"].split("x", 1)[0])
    scale = Decimal(image["scale"].removesuffix("x"))
    return int((size * scale).to_integral_value(rounding=ROUND_HALF_UP))


def declared_outputs(appiconset: Path) -> list[tuple[Path, int]]:
    contents_path = appiconset / "Contents.json"
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    outputs: list[tuple[Path, int]] = []
    for image in contents.get("images", []):
        filename = image.get("filename")
        if not filename:
            continue
        outputs.append((appiconset / filename, target_pixels(image)))
    if not outputs:
        raise ValueError(f"No image filenames found in {contents_path}")
    return outputs


def resize_png(source: Path, output: Path, pixels: int, sips: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f".{output.stem}-",
        suffix=".png",
        dir=output.parent,
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        subprocess.run(
            [
                str(sips),
                "-s",
                "format",
                "png",
                "-z",
                str(pixels),
                str(pixels),
                str(source),
                "--out",
                str(temporary_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        output.unlink(missing_ok=True)
        temporary_path.replace(output)
    finally:
        temporary_path.unlink(missing_ok=True)


def main() -> int:
    args = parse_args()
    source = resolve(args.source)
    appiconset = resolve(args.appiconset)
    sips = resolve(args.sips)

    if not source.is_file():
        print(f"error: source PNG not found: {source}", file=sys.stderr)
        return 2
    if not appiconset.is_dir():
        print(f"error: appiconset not found: {appiconset}", file=sys.stderr)
        return 2
    if not sips.is_file():
        print(f"error: sips executable not found: {sips}", file=sys.stderr)
        return 2

    source_width, source_height = image_dimensions(source, sips)
    if source_width != source_height:
        print(
            f"error: source must be square, got {source_width}x{source_height}: {source}",
            file=sys.stderr,
        )
        return 2

    outputs = declared_outputs(appiconset)
    for output, pixels in outputs:
        if args.dry_run:
            print(f"{output.relative_to(REPO_ROOT)} <- {pixels}x{pixels}")
            continue
        resize_png(source, output, pixels, sips)
        width, height = image_dimensions(output, sips)
        if width != pixels or height != pixels:
            print(
                f"error: generated {output} as {width}x{height}, expected {pixels}x{pixels}",
                file=sys.stderr,
            )
            return 1
        print(f"generated {output.relative_to(REPO_ROOT)} ({pixels}x{pixels})")

    if args.dry_run:
        print(f"planned {len(outputs)} app icon outputs from {source.relative_to(REPO_ROOT)}")
    else:
        print(f"generated {len(outputs)} app icon outputs from {source.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
