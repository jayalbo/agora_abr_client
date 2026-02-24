#!/usr/bin/env python3
"""Generate iOS AppIcon assets from a 1024x1024 source image.

If --input is omitted, a default icon is generated automatically.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


ICON_SPECS = [
    ("iphone", "20x20", "2x", 40, "AppIcon-20@2x.png"),
    ("iphone", "20x20", "3x", 60, "AppIcon-20@3x.png"),
    ("iphone", "29x29", "2x", 58, "AppIcon-29@2x.png"),
    ("iphone", "29x29", "3x", 87, "AppIcon-29@3x.png"),
    ("iphone", "40x40", "2x", 80, "AppIcon-40@2x.png"),
    ("iphone", "40x40", "3x", 120, "AppIcon-40@3x.png"),
    ("iphone", "60x60", "2x", 120, "AppIcon-60@2x.png"),
    ("iphone", "60x60", "3x", 180, "AppIcon-60@3x.png"),
    ("ipad", "20x20", "1x", 20, "AppIcon-20@1x.png"),
    ("ipad", "20x20", "2x", 40, "AppIcon-20@2x~ipad.png"),
    ("ipad", "29x29", "1x", 29, "AppIcon-29@1x~ipad.png"),
    ("ipad", "29x29", "2x", 58, "AppIcon-29@2x~ipad.png"),
    ("ipad", "40x40", "1x", 40, "AppIcon-40@1x~ipad.png"),
    ("ipad", "40x40", "2x", 80, "AppIcon-40@2x~ipad.png"),
    ("ipad", "76x76", "1x", 76, "AppIcon-76@1x.png"),
    ("ipad", "76x76", "2x", 152, "AppIcon-76@2x.png"),
    ("ipad", "83.5x83.5", "2x", 167, "AppIcon-83.5@2x.png"),
    ("ios-marketing", "1024x1024", "1x", 1024, "AppIcon-1024.png"),
]


def generate_default_source(path: Path) -> None:
    size = 1024
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)

    top = (15, 76, 129)
    bottom = (27, 138, 90)
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    inset = 120
    draw.ellipse(
        (inset, inset, size - inset, size - inset),
        outline=(255, 255, 255, 60),
        width=40,
    )

    draw.arc((160, 260, 864, 964), start=205, end=335, fill=(255, 255, 255, 220), width=56)
    draw.arc((220, 390, 804, 950), start=205, end=335, fill=(255, 255, 255, 245), width=44)
    dot = 30
    center_x, center_y = 512, 724
    draw.ellipse(
        (center_x - dot, center_y - dot, center_x + dot, center_y + dot),
        fill=(255, 255, 255, 255),
    )

    img.save(path, "PNG")


def make_appicon_contents_json() -> dict:
    images = []
    for idiom, size_label, scale, _, filename in ICON_SPECS:
        images.append(
            {
                "idiom": idiom,
                "size": size_label,
                "scale": scale,
                "filename": filename,
            }
        )

    return {"images": images, "info": {"version": 1, "author": "xcode"}}


def generate_icons(source: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as original:
        image = original.convert("RGBA")
        if image.size != (1024, 1024):
            image = image.resize((1024, 1024), Image.Resampling.LANCZOS)

        for _, _, _, px_size, filename in ICON_SPECS:
            resized = image.resize((px_size, px_size), Image.Resampling.LANCZOS)
            resized.save(output_dir / filename, "PNG")

    (output_dir / "Contents.json").write_text(
        json.dumps(make_appicon_contents_json(), indent=2) + "\n",
        encoding="utf-8",
    )
    assets_catalog_dir = output_dir.parent
    (assets_catalog_dir / "Contents.json").write_text(
        json.dumps({"info": {"version": 1, "author": "xcode"}}, indent=2) + "\n",
        encoding="utf-8",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        help="Path to a source PNG image. If omitted, a default icon is generated.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    appicon_dir = (
        root / "AgoraABRAudience" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
    )
    source_path = appicon_dir / "app-icon-source-1024.png"
    appicon_dir.mkdir(parents=True, exist_ok=True)

    if args.input:
        input_path = args.input.resolve()
        if not input_path.exists():
            raise FileNotFoundError(f"Input file does not exist: {input_path}")
        with Image.open(input_path) as provided:
            provided.convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS).save(
                source_path, "PNG"
            )
    elif not source_path.exists():
        generate_default_source(source_path)

    generate_icons(source_path, appicon_dir)
    print(f"Generated iOS app icons in: {appicon_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
