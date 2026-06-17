#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing" / "iap"
ICON = ROOT / "iTunesArtwork@2x.png"
SIZE = 1024
SCALE = 3
W = H = SIZE * SCALE


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size * SCALE, index=1 if bold and path.endswith(".ttc") else 0)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def gradient(top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (W, H), top)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        color = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(W):
            px[x, y] = color
    return img


def paste_shadowed(base: Image.Image, item: Image.Image, xy: tuple[int, int], radius: int = 36, alpha: int = 92) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sx, sy = xy[0] + 8 * SCALE, xy[1] + 18 * SCALE
    shadow.alpha_composite(item, (sx, sy))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius * SCALE))
    shadow_alpha = shadow.getchannel("A").point(lambda p: min(alpha, p))
    shadow.putalpha(shadow_alpha)
    base.alpha_composite(shadow)
    base.alpha_composite(item, xy)


def key_tile(label: str, fill: tuple[int, int, int], accent: tuple[int, int, int], text: str = "white") -> Image.Image:
    tile = Image.new("RGBA", (210 * SCALE, 210 * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((0, 0, tile.width - 1, tile.height - 1), radius=46 * SCALE, fill=fill + (255,))
    d.rounded_rectangle(
        (9 * SCALE, 9 * SCALE, tile.width - 10 * SCALE, tile.height - 10 * SCALE),
        radius=38 * SCALE,
        outline=accent + (130,),
        width=5 * SCALE,
    )
    label_font = font(70 if len(label) <= 2 else 54, bold=True)
    bbox = d.textbbox((0, 0), label, font=label_font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    color = (255, 255, 255, 255) if text == "white" else (22, 42, 64, 255)
    d.text(((tile.width - tw) / 2, (tile.height - th) / 2 - 8 * SCALE), label, font=label_font, fill=color)
    return tile


def base_icon_card(size: int = 496) -> Image.Image:
    icon = Image.open(ICON).convert("RGBA").resize((size * SCALE, size * SCALE), Image.Resampling.LANCZOS)
    card = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    mask = rounded_mask(icon.width, 96 * SCALE)
    card.paste(icon, (0, 0), mask)
    return card


def draw_pack_glyphs(layer: Image.Image) -> None:
    d = ImageDraw.Draw(layer)
    labels = ["+", "%", "0x", "$", "#", "12"]
    colors = [
        ((78, 196, 255), (255, 255, 255)),
        ((95, 220, 160), (255, 255, 255)),
        ((36, 132, 255), (255, 255, 255)),
        ((255, 195, 75), (255, 255, 255)),
        ((145, 118, 255), (255, 255, 255)),
        ((31, 48, 80), (255, 255, 255)),
    ]
    positions = [(120, 142), (732, 132), (98, 694), (760, 714), (624, 594), (256, 676)]
    for label, (fill, outline), (x, y) in zip(labels, colors, positions):
        tile = key_tile(label, fill, outline)
        angle = -10 if x < 400 else 9
        rotated = tile.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
        paste_shadowed(layer, rotated, (x * SCALE, y * SCALE), radius=24, alpha=70)


def draw_star(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, fill: tuple[int, int, int, int]) -> None:
    import math

    cx, cy = center
    points: list[tuple[float, float]] = []
    for i in range(10):
        r = radius if i % 2 == 0 else radius * 0.43
        a = -math.pi / 2 + i * math.pi / 5
        points.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    draw.polygon(points, fill=fill)


def pro_image() -> Image.Image:
    bg = gradient((28, 137, 246), (8, 83, 186)).convert("RGBA")
    d = ImageDraw.Draw(bg)
    for label, xy, opacity in [
        ("+", (72, 30), 36),
        ("%", (710, 84), 40),
        ("0x", (48, 772), 30),
        ("#12", (610, 760), 28),
    ]:
        f = font(170 if len(label) <= 2 else 138, bold=True)
        d.text((xy[0] * SCALE, xy[1] * SCALE), label, font=f, fill=(255, 255, 255, opacity))

    draw_pack_glyphs(bg)
    icon = base_icon_card(500)
    paste_shadowed(bg, icon, (262 * SCALE, 224 * SCALE), radius=34, alpha=98)

    ribbon = Image.new("RGBA", (390 * SCALE, 124 * SCALE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ribbon)
    rd.rounded_rectangle((0, 0, ribbon.width - 1, ribbon.height - 1), radius=62 * SCALE, fill=(255, 255, 255, 238))
    draw_star(rd, (82 * SCALE, 62 * SCALE), 42 * SCALE, (255, 185, 42, 255))
    pro_font = font(60, bold=True)
    rd.text((142 * SCALE, 32 * SCALE), "PRO", font=pro_font, fill=(18, 98, 198, 255))
    paste_shadowed(bg, ribbon, (317 * SCALE, 735 * SCALE), radius=20, alpha=72)
    return bg.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def finance_image() -> Image.Image:
    bg = gradient((13, 155, 126), (5, 89, 132)).convert("RGBA")
    d = ImageDraw.Draw(bg)
    for label, xy, opacity in [
        ("$", (96, 54), 42),
        ("%", (705, 56), 36),
        ("+", (114, 750), 30),
        ("=", (710, 764), 28),
    ]:
        f = font(200 if len(label) == 1 else 170, bold=True)
        d.text((xy[0] * SCALE, xy[1] * SCALE), label, font=f, fill=(255, 255, 255, opacity))

    pad = Image.new("RGBA", (568 * SCALE, 568 * SCALE), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pad)
    pd.rounded_rectangle((0, 0, pad.width - 1, pad.height - 1), radius=110 * SCALE, fill=(255, 255, 255, 242))
    labels = ["$", "%", "+", "7", "8", "9", "4", "5", "6"]
    for idx, label in enumerate(labels):
        col = idx % 3
        row = idx // 3
        x = 52 + col * 160
        y = 52 + row * 160
        fill = (24, 151, 127) if idx < 3 else (45, 139, 245)
        tile = key_tile(label, fill, (255, 255, 255))
        tile = tile.resize((120 * SCALE, 120 * SCALE), Image.Resampling.LANCZOS)
        pad.alpha_composite(tile, (x * SCALE, y * SCALE))
    paste_shadowed(bg, pad, (228 * SCALE, 228 * SCALE), radius=36, alpha=100)

    mini_icon = base_icon_card(214)
    paste_shadowed(bg, mini_icon, (405 * SCALE, 43 * SCALE), radius=20, alpha=80)
    return bg.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pro_image().save(OUT / "promo-pro-1024.png", optimize=True)
    finance_image().save(OUT / "promo-finance-1024.png", optimize=True)


if __name__ == "__main__":
    main()
