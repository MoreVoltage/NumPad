#!/usr/bin/env python3
"""Generate the motion-graphic pieces for the NumPad spot.

Outputs (marketing/video/cards/):
  hook_frames/hook_####.png   the "Mode-Switch Hell" opener (animated, 24fps, ~3s)
  cap_1..cap_7.png            transparent caption overlays (1080x1920) for each beat
  outro.png                   branded end card (icon + wordmark + tagline + CTA)

The hook is motion graphics (commercial-only; Apple's screen-recording rule applies to
the App Store preview, which uses real captures instead). Captions are overlaid on the
real screen captures by build_video.py.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "marketing" / "assets"
ICON = Path(__file__).resolve().parents[2] / "iTunesArtwork@2x.png"
OUT = Path(__file__).resolve().parent / "cards"
HOOK = OUT / "hook_frames"
W, H = 1080, 1920

ACCENT = (38, 139, 246)
RED = (235, 64, 52)


def font(sz, bold=True):
    name = "NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf"
    try:
        return ImageFont.truetype(str(ASSETS / name), sz)
    except OSError:
        return ImageFont.load_default()


def vgrad(top, bottom, w, h):
    import numpy as np
    t = np.linspace(0, 1, h, dtype="float32")[:, None]
    rows = (np.array(top, "float32")[None] * (1 - t) + np.array(bottom, "float32")[None] * t)
    import numpy as _np
    arr = _np.ascontiguousarray(_np.broadcast_to(rows[:, None, :], (h, w, 3))).round().astype("uint8")
    return Image.fromarray(arr, "RGB")


# ── Captions (transparent overlays with a bottom scrim) ──────────────
CAPTIONS = [
    ("A real numpad.", "In every app."),
    ("Tax & tip,", "one long-press."),
    ("Your recent numbers,", "one tap away."),
    ("Packs & themes", "that fit you."),
    ("Built for iPad,", "too."),
    ("No subscription.", "Yours forever."),
]


def make_caption(idx, title, sub):
    """Caption lives in a TOP band (the clip is bottom-anchored), so text sits in clean space."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    import numpy as np
    band_h = 430
    grad = np.zeros((band_h, W, 4), "uint8")
    for i in range(band_h):
        a = int(225 * (1 - i / band_h) ** 1.3)  # opaque at very top, fading down
        grad[i, :, 3] = a
    scrim = Image.fromarray(grad, "RGBA")
    img.paste(scrim, (0, 0), scrim)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((90, 110, 90 + 96, 110 + 12), radius=6, fill=ACCENT + (255,))
    d.text((90, 142), title, font=font(94), fill=(255, 255, 255, 255))
    d.text((90, 262), sub, font=font(94), fill=(255, 255, 255, 255))
    img.save(OUT / f"cap_{idx}.png")


def make_outro():
    bg = vgrad((20, 24, 38), (12, 14, 22), W, H).convert("RGBA")
    d = ImageDraw.Draw(bg)
    # icon
    try:
        ic = Image.open(ICON).convert("RGBA").resize((300, 300), Image.LANCZOS)
        m = Image.new("L", ic.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 300, 300), radius=66, fill=255)
        bg.paste(ic, (W // 2 - 150, 560), m)
    except OSError:
        pass
    d.text((W // 2, 960), "NumPad", font=font(150), fill=(255, 255, 255, 255), anchor="mm")
    d.text((W // 2, 1090), "Your number pad.", font=font(64, bold=False), fill=(180, 196, 220, 255), anchor="mm")
    # App Store CTA pill
    pill = (W // 2 - 300, 1260, W // 2 + 300, 1380)
    d.rounded_rectangle(pill, radius=60, fill=(255, 255, 255, 255))
    d.text((W // 2, 1320), "Download on the App Store", font=font(44), fill=(18, 20, 28, 255), anchor="mm")
    bg.convert("RGB").save(OUT / "outro.png")


# ── Animated hook: "Mode-Switch Hell" ───────────────────────────────
LETTERS = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
NUMBERS = ["1234567890", "-/:;()$&@", '.,?!\'"+=']


def draw_phone(field_text, layout, highlight_toggle, tap, error):
    img = vgrad((243, 244, 247), (228, 231, 238), W, H).convert("RGB")
    d = ImageDraw.Draw(img)
    # status bar
    d.text((60, 50), "9:41", font=font(40), fill=(20, 24, 32))
    # title + field card
    d.text((80, 200), "Enter verification code", font=font(56), fill=(28, 32, 42))
    fbox = (80, 320, W - 80, 470)
    border = RED if error else (210, 214, 222)
    d.rounded_rectangle(fbox, radius=24, fill=(255, 255, 255), outline=border, width=6 if error else 3)
    d.text((110, 395), field_text or "", font=font(64), fill=(20, 24, 32), anchor="lm")
    # caret
    if not error:
        tw = d.textlength(field_text or "", font=font(64))
        d.rounded_rectangle((110 + tw + 6, 365, 110 + tw + 12, 425), radius=3, fill=ACCENT)
    if error:
        d.text((84, 500), "Invalid code", font=font(40), fill=RED)

    # keyboard region
    ky0 = 1150
    d.rectangle((0, ky0, W, H), fill=(209, 213, 219))
    rows = LETTERS if layout == "letters" else NUMBERS
    kh = 150
    pad = 16
    for r, row in enumerate(rows):
        n = len(row)
        kw = (W - pad * 2 - (n - 1) * 12) / n
        y0 = ky0 + 30 + r * (kh + 18)
        for c, ch in enumerate(row):
            x0 = pad + c * (kw + 12)
            d.rounded_rectangle((x0, y0, x0 + kw, y0 + kh), radius=14, fill=(255, 255, 255))
            d.text((x0 + kw / 2, y0 + kh / 2), ch, font=font(52, bold=False), fill=(20, 24, 32), anchor="mm")
    # bottom row: toggle | space | return
    by0 = ky0 + 30 + 3 * (kh + 18)
    toggle_label = "123" if layout == "letters" else "ABC"
    tg = (pad, by0, pad + 240, by0 + kh)
    d.rounded_rectangle(tg, radius=14, fill=ACCENT if highlight_toggle else (180, 186, 196))
    d.text(((tg[0] + tg[2]) / 2, by0 + kh / 2), toggle_label, font=font(48),
           fill=(255, 255, 255) if highlight_toggle else (40, 44, 54), anchor="mm")
    sp = (pad + 252, by0, W - 280, by0 + kh)
    d.rounded_rectangle(sp, radius=14, fill=(255, 255, 255))
    d.text(((sp[0] + sp[2]) / 2, by0 + kh / 2), "space", font=font(40, bold=False), fill=(120, 126, 136), anchor="mm")
    rt = (W - 268, by0, W - pad, by0 + kh)
    d.rounded_rectangle(rt, radius=14, fill=(180, 186, 196))
    d.text(((rt[0] + rt[2]) / 2, by0 + kh / 2), "return", font=font(36), fill=(40, 44, 54), anchor="mm")
    # finger tap indicator on the toggle
    if tap:
        cx, cy = (tg[0] + tg[2]) / 2, by0 + kh / 2
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).ellipse((cx - 70, cy - 70, cx + 70, cy + 70), fill=(38, 139, 246, 90))
        img = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")
    return img


def hook_state(f, fps=24):
    """Map frame -> (field, layout, highlight_toggle, tap, error). ~3.0s story."""
    t = f / fps
    if t < 0.5:      return ("", "letters", True, True, False)      # jab 123
    if t < 0.75:     return ("4", "numbers", False, False, False)
    if t < 1.0:      return ("49", "numbers", False, False, False)
    if t < 1.5:      return ("49", "letters", True, True, False)     # flips back, frustration
    if t < 1.75:     return ("49i", "letters", False, False, False)  # wrong char
    if t < 2.0:      return ("49", "letters", False, False, False)   # backspace
    if t < 2.25:     return ("4", "numbers", True, True, False)      # jab 123 again
    if t < 2.6:      return ("491", "numbers", False, False, False)
    return ("491", "numbers", False, False, True)                    # Invalid


def make_hook(fps=24, dur=3.0):
    HOOK.mkdir(parents=True, exist_ok=True)
    nf = int(fps * dur)
    for f in range(nf):
        field, layout, hl, tap, err = hook_state(f, fps)
        img = draw_phone(field, layout, hl, tap, err)
        img.save(HOOK / f"hook_{f:04d}.png")
    print(f"  wrote {nf} hook frames")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (title, sub) in enumerate(CAPTIONS, start=1):
        make_caption(i, title, sub)
    make_outro()
    make_hook()
    print("cards done")
