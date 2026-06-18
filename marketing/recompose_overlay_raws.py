#!/usr/bin/env python3
"""Create neutral host-app raw screenshots for overlay marketing slides."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "marketing" / "raw"
ASSETS = ROOT / "marketing" / "assets"

W, H = 1320, 2868


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf"
    return ImageFont.truetype(str(ASSETS / name), size)


def draw_status_bar(draw: ImageDraw.ImageDraw) -> None:
    draw.text((70, 58), "9:41", font=font(42, bold=True), fill=(17, 24, 39))
    draw.rounded_rectangle((510, 42, 810, 112), radius=38, fill=(0, 0, 0))
    draw.rounded_rectangle((1144, 66, 1218, 98), radius=15, outline=(36, 43, 56), width=4)
    draw.rounded_rectangle((1152, 73, 1204, 91), radius=8, fill=(36, 43, 56))
    draw.rounded_rectangle((1222, 76, 1230, 90), radius=4, fill=(36, 43, 56))


def draw_note_host(title: str, lines: list[tuple[str, str]], accent: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    draw_status_bar(d)

    d.text((70, 164), "Notes", font=font(42, bold=True), fill=accent)
    d.text((70, 240), title, font=font(58, bold=True), fill=(17, 24, 39))
    d.rounded_rectangle((68, 336, 1252, 354), radius=9, fill=(238, 242, 247))

    # Spread the note body lower so the screen reads as a full, in-use note
    # instead of leaving a large empty gap above the keyboard.
    y = 470
    for label, value in lines:
        d.text((92, y), label, font=font(36), fill=(100, 116, 139))
        d.text((460, y), value, font=font(42, bold=True), fill=(17, 24, 39))
        y += 150

    # Active text field sits just above where the keyboard will mount.
    field_top = y + 40
    d.rounded_rectangle((84, field_top, 1236, field_top + 250), radius=26, fill=(248, 250, 252), outline=(226, 232, 240), width=2)
    d.text((124, field_top + 92), "Type with NumPad here", font=font(36), fill=(148, 163, 184))
    d.rounded_rectangle((114, field_top + 94, 118, field_top + 144), radius=2, fill=accent)
    return img


def clean_seam(img: Image.Image, crop_y: int, blue_y: int) -> None:
    """Erase the seam between the white Notes host and the composited keyboard.

    The band just above the solid keys (``crop_y``..``blue_y``) carries the
    keyboard's grey input-view chrome and faint host-app bleed behind its
    rounded top corners. Two passes, both deliberately conservative so the
    popup card (white body, thin border, dark text) and the real blue keys are
    never altered:

      1. Grey chrome / shadow anywhere in the band  -> white.
      2. Bright-blue corner bleed, only in the outer ~140px columns and only in
         the thin seam strip near ``crop_y`` -> white. Real keys are full-width
         and start at ``blue_y``, so the corner-and-strip guard can't hit them.
    """
    px = img.load()
    corner = 200  # left/right gutter where corner bleed appears
    strip_bottom = crop_y + 60  # blue bleed only lives right at the seam
    for yy in range(crop_y - 8, blue_y):
        for xx in range(W):
            r, g, b, a = px[xx, yy]
            is_grey = abs(r - g) < 16 and abs(g - b) < 18 and 190 <= r <= 246
            in_corner = xx < corner or xx > (W - corner)
            is_blue_bleed = (
                in_corner and yy < strip_bottom and b > 235 and g > 165 and r < 130
            )
            if is_grey or is_blue_bleed:
                px[xx, yy] = (255, 255, 255, 255)


def paste_keyboard(host: Image.Image, source_name: str, crop_y: int, blue_y: int) -> Image.Image:
    source = Image.open(RAW / source_name).convert("RGBA")
    host.alpha_composite(source.crop((0, crop_y, W, H)), (0, crop_y))
    clean_seam(host, crop_y, blue_y)
    return host


def main() -> None:
    tax_host = draw_note_host(
        "Dinner total",
        [
            ("Subtotal", "$80.00"),
            ("Tax", "8%"),
            ("Tip", "18%"),
            ("Total", "calculating..."),
        ],
        (0, 122, 255),
    )
    paste_keyboard(tax_host, "03-taxtip-settings.png", 1950, 1983).save(RAW / "03-taxtip.png")

    clipboard_host = draw_note_host(
        "Invoice notes",
        [
            ("Invoice", "1,249.99"),
            ("Phone", "555-867-5309"),
            ("Order", "1249-4912-4218"),
            ("Paste", "recent numbers"),
        ],
        (0, 122, 255),
    )
    paste_keyboard(clipboard_host, "04-clipboard-settings.png", 1690, 1743).save(RAW / "04-clipboard.png")

    print("Wrote marketing/raw/03-taxtip.png")
    print("Wrote marketing/raw/04-clipboard.png")


if __name__ == "__main__":
    main()
