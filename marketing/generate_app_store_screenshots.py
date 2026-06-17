#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "marketing" / "raw"
OUT = ROOT / "marketing" / "app-store"
ICON = ROOT / "iTunesArtwork@2x.png"
MOCKUP = Path("/Users/jamespikover/.agents/skills/app-store-screenshots/mockup.png")

CANVAS_W = 1320
CANVAS_H = 2868

SIZES = {
    "iphone-6.9": (1320, 2868),
    "iphone-6.5": (1284, 2778),
    "iphone-6.3": (1206, 2622),
    "iphone-6.1": (1125, 2436),
}


@dataclass(frozen=True)
class Slide:
    slug: str
    source: str
    headline: str
    subline: str
    top: tuple[int, int, int]
    bottom: tuple[int, int, int]
    accent: tuple[int, int, int]
    phone_width: int = 780
    phone_y: int = 900
    phone_x: int = 270
    scrub_y: int | None = None
    dark_text: bool = False


SLIDES = [
    Slide(
        slug="01-numbers-without-slowdowns",
        source="01-hero.png",
        headline="Numbers\nwithout\nslowdowns",
        subline="A real numpad in every app.",
        top=(238, 249, 255),
        bottom=(198, 236, 227),
        accent=(38, 139, 246),
        phone_width=820,
        phone_y=910,
        phone_x=250,
        scrub_y=1590,
        dark_text=True,
    ),
    Slide(
        slug="02-faster-forms",
        source="02-checkout.png",
        headline="Faster\nforms",
        subline="Card numbers, codes, totals.",
        top=(24, 126, 224),
        bottom=(11, 86, 167),
        accent=(101, 232, 226),
        phone_width=790,
        phone_y=920,
        phone_x=265,
        scrub_y=1360,
    ),
    Slide(
        slug="03-tax-and-tip",
        source="03-taxtip.png",
        headline="Tax and tip\nin one tap",
        subline="Long-press % when totals matter.",
        top=(246, 250, 252),
        bottom=(255, 239, 220),
        accent=(255, 149, 0),
        phone_width=800,
        phone_y=880,
        phone_x=260,
        dark_text=True,
    ),
    Slide(
        slug="04-paste-recent-numbers",
        source="04-clipboard.png",
        headline="Paste recent\nnumbers",
        subline="Clipboard history stays on-device.",
        top=(8, 120, 111),
        bottom=(7, 63, 92),
        accent=(85, 223, 168),
        phone_width=790,
        phone_y=910,
        phone_x=265,
    ),
    Slide(
        slug="05-pro-packs-for-work",
        source="08-dark-programmer.png",
        headline="Pro packs\nfor work",
        subline="Finance, symbols, math, code.",
        top=(26, 29, 41),
        bottom=(73, 57, 117),
        accent=(144, 118, 255),
        phone_width=790,
        phone_y=905,
        phone_x=265,
    ),
    Slide(
        slug="06-your-numpad-your-style",
        source="05-themes.png",
        headline="Your numpad\nyour style",
        subline="Themes that fit the moment.",
        top=(255, 249, 240),
        bottom=(230, 247, 255),
        accent=(255, 59, 48),
        phone_width=800,
        phone_y=900,
        phone_x=260,
        dark_text=True,
    ),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size, index=1 if bold and candidate.endswith(".ttc") else 0)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(top: tuple[int, int, int], bottom: tuple[int, int, int], w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), top)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        row = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = row
    return img.convert("RGBA")


def draw_key_pattern(draw: ImageDraw.ImageDraw, slide: Slide) -> None:
    labels = ["#", "2", "0x", "+", "%", "3"]
    positions = [(930, 300), (1036, 720), (74, 1240), (1030, 1420), (1028, 2350), (82, 2420)]
    fill = (255, 255, 255, 44 if not slide.dark_text else 82)
    outline = slide.accent + (80,)
    key_font = font(82, bold=True)
    for index, (label, (x, y)) in enumerate(zip(labels, positions)):
        w = 188 if len(label) <= 1 else 226
        h = 150
        radius = 36
        draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=fill, outline=outline, width=3)
        box = draw.textbbox((0, 0), label, font=key_font)
        tx = x + (w - (box[2] - box[0])) / 2
        ty = y + (h - (box[3] - box[1])) / 2 - 8
        alpha = 100 if slide.dark_text else 128
        draw.text((tx, ty), label, font=key_font, fill=slide.accent + (alpha,))


def scrub_capture(img: Image.Image, y: int | None) -> Image.Image:
    if y is None:
        return img
    cleaned = img.copy()
    d = ImageDraw.Draw(cleaned)
    x1, y1, x2, y2 = 470, y, 850, y + 118
    d.rounded_rectangle((x1, y1, x2, y2), radius=58, fill=(255, 255, 255, 255))
    return cleaned


def make_phone(source: Path, width: int, scrub_y: int | None) -> Image.Image:
    mockup = Image.open(MOCKUP).convert("RGBA")
    shot = scrub_capture(Image.open(source).convert("RGBA"), scrub_y)
    scale = width / mockup.width
    phone = mockup.resize((width, round(mockup.height * scale)), Image.Resampling.LANCZOS)

    sc_l = round((52 / 1022) * phone.width)
    sc_t = round((46 / 2082) * phone.height)
    sc_w = round((918 / 1022) * phone.width)
    sc_h = round((1990 / 2082) * phone.height)

    screen = shot.resize((sc_w, sc_h), Image.Resampling.LANCZOS)
    mask = Image.new("L", (sc_w, sc_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sc_w, sc_h), radius=round(sc_w * 0.13), fill=255)
    phone.paste(screen, (sc_l, sc_t), mask)
    return phone


def shadow_layer(item: Image.Image, xy: tuple[int, int], canvas_size: tuple[int, int]) -> Image.Image:
    shadow = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    shadow.alpha_composite(item, (xy[0] + 16, xy[1] + 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    shadow.putalpha(shadow.getchannel("A").point(lambda p: min(110, p)))
    return shadow


def draw_multiline(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], font_obj: ImageFont.FreeTypeFont, fill: tuple[int, int, int, int], line_gap: int) -> int:
    x, y = xy
    for line in text.splitlines():
        draw.text((x, y), line, font=font_obj, fill=fill)
        bbox = draw.textbbox((x, y), line, font=font_obj)
        y += (bbox[3] - bbox[1]) + line_gap
    return y


def render_slide(slide: Slide) -> Image.Image:
    canvas = gradient(slide.top, slide.bottom, CANVAS_W, CANVAS_H)
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_key_pattern(d, slide)

    text_color = (22, 32, 46, 255) if slide.dark_text else (255, 255, 255, 255)
    muted = (63, 76, 92, 230) if slide.dark_text else (235, 247, 255, 230)

    icon = Image.open(ICON).convert("RGBA").resize((136, 136), Image.Resampling.LANCZOS)
    icon_mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(icon_mask).rounded_rectangle((0, 0, icon.width, icon.height), radius=30, fill=255)
    d.rounded_rectangle((86, 106, 236, 256), radius=34, fill=(255, 255, 255, 92 if not slide.dark_text else 190))
    canvas.paste(icon, (93, 113), icon_mask)
    d.text((266, 142), "NumPad", font=font(48, bold=True), fill=text_color)
    d.text((266, 202), "Number Pad Keyboard", font=font(30), fill=muted)

    draw_multiline(d, slide.headline, (86, 340), font(128, bold=True), text_color, 14)
    d.text((90, 730), slide.subline, font=font(38), fill=muted)

    phone = make_phone(RAW / slide.source, slide.phone_width, slide.scrub_y)
    xy = (slide.phone_x, slide.phone_y)
    canvas.alpha_composite(shadow_layer(phone, xy, canvas.size))
    canvas.alpha_composite(phone, xy)

    footer_fill = (255, 255, 255, 190) if slide.dark_text else (8, 24, 38, 132)
    footer_color = (24, 48, 74, 230) if slide.dark_text else (255, 255, 255, 238)
    d.rounded_rectangle((86, 2622, 1234, 2724), radius=50, fill=footer_fill)
    d.text((132, 2654), "No subscription required for Pro.", font=font(34, bold=True), fill=footer_color)
    d.text((840, 2654), "Works in any app", font=font(34, bold=True), fill=footer_color)
    return canvas.convert("RGB")


def main() -> None:
    base_dir = OUT / "iphone-6.9"
    base_dir.mkdir(parents=True, exist_ok=True)
    rendered: list[tuple[str, Image.Image]] = []
    for slide in SLIDES:
        img = render_slide(slide)
        filename = f"{slide.slug}-1320x2868.png"
        img.save(base_dir / filename, optimize=True)
        rendered.append((slide.slug, img))

    for size_name, (w, h) in SIZES.items():
        if size_name == "iphone-6.9":
            continue
        size_dir = OUT / size_name
        size_dir.mkdir(parents=True, exist_ok=True)
        for slug, img in rendered:
            img.resize((w, h), Image.Resampling.LANCZOS).save(size_dir / f"{slug}-{w}x{h}.png", optimize=True)


if __name__ == "__main__":
    main()
