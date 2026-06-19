#!/usr/bin/env python3
"""NumPad commercial — fully rendered motion graphics (no app settings screen, ever).

Every frame is drawn from scratch: animated app UI shown in REAL contexts (Notes, a
checkout, a spreadsheet), kinetic typography, drifting keycaps, light sweeps, spring
pop-ins, and fast cuts. Designed to read even silently / as a poster.

Usage:
  python3 build_commercial.py strip                 # 1 contact sheet to judge the look (fast)
  python3 build_commercial.py frames <a> <b>        # render frame range -> out/cframes/
  python3 build_commercial.py encode                # frames + audio -> out/*.mp4 + poster
  python3 build_commercial.py plan                  # print the scene timeline
"""
from __future__ import annotations
import math, sys, subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

V = Path(__file__).resolve().parent
ASSETS = V.parents[0] / "assets"
ICON = V.parents[1] / "iTunesArtwork@2x.png"
OUT = V / "out"
CF = OUT / "cframes"
W, H, FPS = 1080, 1920, 30

# Palette
INK0, INK1 = (12, 16, 30), (5, 7, 16)
BLUE = (46, 139, 255)
MINT = (77, 225, 193)
VIOLET = (139, 124, 255)
CORAL = (255, 107, 107)
AMBER = (255, 194, 75)
WHITE = (255, 255, 255)
ACCENTS = [BLUE, MINT, VIOLET, AMBER, CORAL]


def font(sz, bold=True):
    name = "NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf"
    try:
        return ImageFont.truetype(str(ASSETS / name), sz)
    except OSError:
        return ImageFont.load_default()


# ── easing ───────────────────────────────────────────────────────────
def clamp01(x): return 0.0 if x < 0 else 1.0 if x > 1 else x
def eo_cubic(x): x = clamp01(x); return 1 - (1 - x) ** 3
def ei_cubic(x): x = clamp01(x); return x * x * x
def eio(x):
    x = clamp01(x)
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2
def eo_back(x, s=1.70158):
    x = clamp01(x); c3 = s + 1
    return 1 + c3 * (x - 1) ** 3 + s * (x - 1) ** 2
def lerp(a, b, t): return a + (b - a) * t
def lerpc(c1, c2, t): return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


# ── background ───────────────────────────────────────────────────────
_grad_cache = {}
def _grad(c1, c2):
    key = (c1, c2)
    if key not in _grad_cache:
        t = np.linspace(0, 1, H, dtype="float32")[:, None]
        rows = np.array(c1, "float32")[None] * (1 - t) + np.array(c2, "float32")[None] * t
        _grad_cache[key] = np.ascontiguousarray(np.broadcast_to(rows[:, None, :], (H, W, 3))).astype("uint8")
    return _grad_cache[key]


# drifting keycaps (precomputed)
_RNG = np.random.default_rng(11)
_PARTS = []
for _ in range(16):
    _PARTS.append(dict(
        x=int(_RNG.uniform(40, W - 140)), y0=_RNG.uniform(0, H),
        spd=_RNG.uniform(18, 46), size=int(_RNG.uniform(54, 120)),
        ch=_RNG.choice(list("0123456789+%#$")), rot=_RNG.uniform(-8, 8),
        col=ACCENTS[int(_RNG.integers(0, len(ACCENTS)))], a=int(_RNG.uniform(16, 40))))


def bg(t, tint=BLUE, glow=0.5):
    base = _grad(INK0, INK1).copy()
    img = Image.fromarray(base, "RGB").convert("RGBA")
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    # soft radial glow near upper third in the scene tint
    gx, gy, gr = W // 2, 560, 720
    for i in range(6):
        a = int(18 * (1 - i / 6) * glow)
        rr = gr - i * 90
        d.ellipse((gx - rr, gy - rr, gx + rr, gy + rr), fill=tint + (a,))
    # drifting keycaps
    for p in _PARTS:
        y = (p["y0"] - t * p["spd"]) % (H + 200) - 100
        s = p["size"]
        kc = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        kd = ImageDraw.Draw(kc)
        kd.rounded_rectangle((4, 4, s - 4, s - 4), radius=s // 5, outline=p["col"] + (p["a"],), width=3)
        kd.text((s / 2, s / 2 - 4), p["ch"], font=font(int(s * 0.5)), fill=p["col"] + (p["a"] + 10,), anchor="mm")
        lay.alpha_composite(kc.rotate(p["rot"], expand=True), (p["x"], int(y)))
    img.alpha_composite(lay)
    return img


def light_sweep(img, prog, strength=70):
    """diagonal light sweep across the frame at progress 0..1"""
    if prog <= 0 or prog >= 1:
        return img
    lay = Image.new("L", (W, H), 0)
    x = int(lerp(-300, W + 300, prog))
    ImageDraw.Draw(lay).polygon([(x, 0), (x + 160, 0), (x + 360, H), (x + 200, H)], fill=strength)
    lay = lay.filter(ImageFilter.GaussianBlur(60))
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    white.putalpha(lay)
    img.alpha_composite(white)
    return img


# ── device + screen ──────────────────────────────────────────────────
SCR_W, SCR_H = 712, 1480
BEZEL = 26
DEV_W, DEV_H = SCR_W + BEZEL * 2, SCR_H + BEZEL * 2


def device(screen: Image.Image, scale=1.0, cx=W // 2, cy=300 + DEV_H // 2, shadow=True):
    """Composite a screen image into a phone frame onto a transparent 1080x1920 layer."""
    frame = Image.new("RGBA", (DEV_W, DEV_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle((0, 0, DEV_W, DEV_H), radius=86, fill=(22, 24, 30, 255))
    d.rounded_rectangle((3, 3, DEV_W - 3, DEV_H - 3), radius=84, outline=(70, 74, 84, 255), width=2)
    sc = screen.resize((SCR_W, SCR_H), Image.LANCZOS)
    m = Image.new("L", (SCR_W, SCR_H), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, SCR_W, SCR_H), radius=62, fill=255)
    frame.paste(sc, (BEZEL, BEZEL), m)
    if scale != 1.0:
        frame = frame.resize((int(DEV_W * scale), int(DEV_H * scale)), Image.LANCZOS)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px, py = int(cx - frame.width / 2), int(cy - frame.height / 2)
    if shadow:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh.alpha_composite(frame, (px, py + 24))
        sh = sh.filter(ImageFilter.GaussianBlur(40))
        sh.putalpha(sh.getchannel("A").point(lambda v: min(120, v)))
        layer.alpha_composite(sh)
    layer.alpha_composite(frame, (px, py))
    return layer


# ── keyboard (iPhone numpad) ─────────────────────────────────────────
THEMES = {
    "blue": dict(bg=(228, 231, 238), key=(46, 139, 255), key2=(70, 152, 255), text=WHITE, press=(120, 184, 255)),
    "white": dict(bg=(225, 225, 228), key=WHITE, key2=(242, 242, 245), text=(20, 22, 28), press=(196, 220, 255)),
    "indigo": dict(bg=(70, 84, 173), key=(63, 81, 181), key2=(80, 98, 196), text=WHITE, press=(132, 146, 226)),
    "teal": dict(bg=(20, 150, 138), key=(0, 150, 136), key2=(20, 165, 150), text=WHITE, press=(120, 210, 200)),
    "violet": dict(bg=(120, 96, 210), key=(103, 58, 183), key2=(124, 86, 198), text=WHITE, press=(176, 150, 230)),
    "ink": dict(bg=(38, 40, 48), key=(26, 28, 34), key2=(46, 49, 58), text=WHITE, press=(96, 100, 112)),
}


def draw_keyboard(d, area, theme="blue", pressed=None, pack=None):
    th = THEMES[theme]
    x0, y0, x1, y1 = area
    d.rectangle(area, fill=th["bg"])
    gap = 8
    pad = 10
    rows = [["1", "2", "3", ","], ["4", "5", "6", "."], ["7", "8", "9", "⌫"], ["⌨", "0", "space", "↵"]]
    gx0, gy0, gx1, gy1 = x0 + pad, y0 + pad, x1 - pad, y1 - pad
    if pack:
        ph = 84
        n = len(pack)
        kw = (gx1 - gx0 - (n - 1) * gap) / n
        for i, g in enumerate(pack):
            kx = gx0 + i * (kw + gap)
            d.rounded_rectangle((kx, gy0, kx + kw, gy0 + ph), radius=10, fill=th["key2"])
            d.text((kx + kw / 2, gy0 + ph / 2), g, font=font(34, False), fill=th["text"], anchor="mm")
        gy0 += ph + gap
    cw = (gx1 - gx0 - 3 * gap) / 4
    rh = (gy1 - gy0 - 3 * gap) / 4
    for r, row in enumerate(rows):
        for c, lab in enumerate(row):
            kx0 = gx0 + c * (cw + gap)
            ky0 = gy0 + r * (rh + gap)
            box = (kx0, ky0, kx0 + cw, ky0 + rh)
            special = lab in ("⌫", "⌨", "↵", "space", ",", ".")
            fill = th["key2"] if special else th["key"]
            lift = 0
            if pressed == (r, c):
                fill = th["press"]; lift = 4
            d.rounded_rectangle((box[0], box[1] - lift, box[2], box[3] - lift), radius=12, fill=fill)
            sz = 30 if (special and lab in ("space",)) else 46
            d.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 - lift), lab,
                   font=font(sz, False), fill=th["text"], anchor="mm")


# overlay band (iPhone: tax/tip & clipboard appear as a band above the keys)
def overlay_taxtip(d, area, prog):
    x0, y0, x1, y1 = area
    yo = int(lerp(y1, y0, eo_back(prog)))  # slide up from keyboard
    d.rounded_rectangle((x0 + 10, yo, x1 - 10, y1), radius=18, fill=(255, 255, 255))
    d.text(((x0 + x1) / 2, yo + 40, ), "TAX / TIP", font=font(30), fill=(20, 22, 28), anchor="mm")
    chips_y = yo + 96
    for lab, opts, sel in [("Tax", ["0", "5", "8", "10", "13"], 2), ("Tip", ["0", "15", "18", "20", "25"], 2)]:
        d.text((x0 + 36, chips_y + 24), lab, font=font(26, False), fill=(120, 124, 134), anchor="lm")
        sx = x0 + 150
        sw = (x1 - 40 - sx) / len(opts)
        for i, o in enumerate(opts):
            bx = sx + i * sw
            on = i == sel
            d.rounded_rectangle((bx + 4, chips_y, bx + sw - 4, chips_y + 50), radius=10,
                                fill=BLUE if on else (236, 238, 242))
            d.text((bx + sw / 2, chips_y + 25), o, font=font(24, False),
                   fill=WHITE if on else (40, 44, 54), anchor="mm")
        chips_y += 70
    total = lerp(80.0, 97.20, eo_cubic(prog))
    d.rounded_rectangle((x0 + 36, chips_y + 8, x1 - 36, chips_y + 78), radius=14, fill=(232, 247, 238))
    d.text((x0 + 56, chips_y + 43), "Total", font=font(26, False), fill=(120, 124, 134), anchor="lm")
    d.text((x1 - 56, chips_y + 43), f"${total:,.2f}", font=font(36), fill=(20, 130, 70), anchor="rm")


def overlay_clipboard(d, area, prog, pulled=0):
    x0, y0, x1, y1 = area
    yo = int(lerp(y1, y0, eo_back(prog)))
    d.rounded_rectangle((x0 + 10, yo, x1 - 10, y1), radius=18, fill=(255, 255, 255))
    d.text((x0 + 36, yo + 36), "Clipboard History", font=font(28), fill=(20, 22, 28), anchor="lm")
    rows = ["1,249.99", "555-867-5309", "1249-4912-4218", "$80.00", "4012 8888 8888 1881"]
    ry = yo + 84
    for i, r in enumerate(rows):
        hot = (i == 2 and pulled > 0)
        if hot:
            d.rounded_rectangle((x0 + 22, ry - 6, x1 - 22, ry + 46), radius=10, fill=(225, 239, 255))
        d.line((x0 + 30, ry + 52, x1 - 30, ry + 52), fill=(232, 234, 240), width=2)
        d.text((x0 + 40, ry + 22), r, font=font(28, False), fill=(28, 30, 38), anchor="lm")
        ry += 64


# ── host screens (real contexts) ─────────────────────────────────────
def screen_base(host="notes"):
    img = Image.new("RGB", (SCR_W, SCR_H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((34, 28), "9:41", font=font(28), fill=(20, 24, 32))
    d.ellipse((SCR_W - 86, 30, SCR_W - 40, 50), fill=(20, 24, 32))  # status dot cluster (simplified)
    return img, d


def host_notes(typed, caret=True):
    img, d = screen_base()
    d.text((36, 96), "Notes", font=font(30), fill=BLUE)
    d.text((36, 150), "Expenses", font=font(54), fill=(17, 20, 28))
    d.line((34, 232, SCR_W - 34, 232), fill=(238, 240, 246), width=3)
    rows = [("Lunch", "18.50"), ("Taxi", "24.00"), ("Supplies", typed)]
    y = 290
    for i, (k, v) in enumerate(rows):
        d.text((44, y), k, font=font(34, False), fill=(110, 116, 130))
        active = (i == len(rows) - 1)
        d.text((300, y), v, font=font(40), fill=(17, 20, 28))
        if active and caret:
            tw = d.textlength(v, font=font(40))
            d.rounded_rectangle((300 + tw + 6, y - 4, 300 + tw + 12, y + 44), radius=3, fill=BLUE)
        y += 92
    return img


def host_checkout(typed):
    img, d = screen_base()
    d.text((SCR_W / 2, 110), "Checkout", font=font(40), fill=(17, 20, 28), anchor="mm")
    d.rounded_rectangle((40, 180, SCR_W - 40, 470), radius=22, fill=(247, 248, 251), outline=(232, 236, 242), width=2)
    d.text((64, 220), "Card number", font=font(26, False), fill=(120, 126, 138))
    d.rounded_rectangle((64, 258, SCR_W - 64, 332), radius=14, fill=WHITE, outline=BLUE, width=3)
    d.text((84, 295), typed, font=font(36), fill=(17, 20, 28), anchor="lm")
    d.text((64, 372), "Total", font=font(28, False), fill=(120, 126, 138))
    d.text((SCR_W - 64, 372), "$129.00", font=font(40), fill=(17, 20, 28), anchor="ra")
    return img


def host_sheet(active_val):
    img, d = screen_base()
    d.text((36, 96), "Budget.xlsx", font=font(30), fill=(16, 140, 90))
    cols = ["A", "B", "C", "D"]
    cw = (SCR_W - 60) / len(cols)
    x0 = 30
    for i, c in enumerate(cols):
        d.rectangle((x0 + i * cw, 150, x0 + (i + 1) * cw, 196), fill=(244, 246, 249))
        d.text((x0 + i * cw + cw / 2, 173), c, font=font(26, False), fill=(120, 126, 138), anchor="mm")
    rh = 78
    vals = [["Q1", "120", "98", "210"], ["Q2", "140", "110", active_val], ["Q3", "", "", ""]]
    for r, row in enumerate(vals):
        for cI, v in enumerate(row):
            cellbox = (x0 + cI * cw, 196 + r * rh, x0 + (cI + 1) * cw, 196 + (r + 1) * rh)
            active = (r == 1 and cI == 3)
            if active:
                d.rectangle(cellbox, fill=(225, 239, 255), outline=BLUE, width=4)
            d.rectangle(cellbox, outline=(232, 234, 240), width=1)
            d.text((cellbox[0] + 16, (cellbox[1] + cellbox[3]) / 2), v, font=font(30, False),
                   fill=(28, 30, 38), anchor="lm")
    return img


# screen with keyboard mounted at the bottom; returns full SCR image
def app_screen(host_img, theme="blue", pressed=None, pack=None, overlay=None, ov_prog=1.0, ov_pulled=0):
    img = host_img.copy()
    d = ImageDraw.Draw(img)
    kb_h = 700 if not pack else 760
    area = (0, SCR_H - kb_h, SCR_W, SCR_H)
    draw_keyboard(d, area, theme=theme, pressed=pressed, pack=pack)
    if overlay == "taxtip":
        overlay_taxtip(d, (0, SCR_H - kb_h - 470, SCR_W, SCR_H - kb_h + 8), ov_prog)
    elif overlay == "clipboard":
        overlay_clipboard(d, (0, SCR_H - kb_h - 430, SCR_W, SCR_H - kb_h + 8), ov_prog, ov_pulled)
    return img


# ── kinetic captions ─────────────────────────────────────────────────
def caption(img, lines, tl, dur, accent=BLUE, y=150, size=104):
    """pop-in kinetic caption in the top band; lines: list[(text, is_accent)]"""
    d = ImageDraw.Draw(img)
    appear = eo_back(tl / 0.5)
    out = 1 - eo_cubic((tl - (dur - 0.45)) / 0.45) if tl > dur - 0.45 else 1
    alpha = int(255 * clamp01(out))
    dy = int(lerp(40, 0, clamp01(appear)))
    yy = y + dy
    for text, isacc in lines:
        col = accent if isacc else WHITE
        f = font(size)
        # subtle shadow
        d.text((64 + 3, yy + 3), text, font=f, fill=(0, 0, 0, int(alpha * 0.4)))
        d.text((64, yy), text, font=f, fill=col + (alpha,))
        yy += int(size * 1.12)
    # accent kicker
    d.rounded_rectangle((64, y - 34, 64 + int(120 * clamp01(appear)), y - 22), radius=6, fill=accent + (alpha,))
    return img


def flash(img, tl, color=WHITE, d=0.12):
    if tl < d:
        a = int(200 * (1 - tl / d))
        ov = Image.new("RGBA", (W, H), color + (a,))
        img.alpha_composite(ov)
    return img


# ── SCENES ───────────────────────────────────────────────────────────
SCENES = [
    ("hook", 3.2), ("logo", 1.7), ("notes", 3.6), ("checkout", 2.3), ("sheet", 2.3),
    ("taxtip", 4.2), ("clipboard", 3.6), ("packs", 2.6), ("themes", 2.8),
    ("ipad", 2.8), ("outro", 3.6),
]
TOTAL = sum(d for _, d in SCENES)


def scene_at(t):
    acc = 0.0
    for i, (name, dur) in enumerate(SCENES):
        if t < acc + dur or i == len(SCENES) - 1:
            return name, t - acc, dur
        acc += dur
    return SCENES[-1][0], 0, SCENES[-1][1]


def typed_number(s, prog):
    n = int(round(len(s) * clamp01(prog)))
    return s[:n]


def render(t):
    name, tl, dur = scene_at(t)

    if name == "hook":
        img = bg(t, tint=CORAL, glow=0.7)
        # the fighting keyboard: a checkout field, keyboard flips ABC<->123, wrong char, red invalid
        flip = int(tl * 6) % 2  # rapid mode switching
        layout_letters = flip == 0 and tl < 1.8
        err = tl > 2.5
        field = "49" if tl < 1.4 else ("49i" if tl < 1.9 else ("4" if tl < 2.3 else "491"))
        scr, d = screen_base()
        d.text((SCR_W / 2, 150), "Enter code", font=font(40), fill=(17, 20, 28), anchor="mm")
        bcol = CORAL if err else (210, 214, 222)
        d.rounded_rectangle((60, 230, SCR_W - 60, 350), radius=18, fill=WHITE, outline=bcol, width=8 if err else 3)
        d.text((90, 290), field, font=font(52), fill=(17, 20, 28), anchor="lm")
        if err:
            d.text((64, 372), "Invalid code", font=font(34), fill=CORAL)
        # mini keyboard with a pulsing 123/ABC toggle
        th = THEMES["white"]
        area = (0, SCR_H - 560, SCR_W, SCR_H)
        d.rectangle(area, fill=(214, 217, 223))
        toprow = "QWERTYUIOP" if layout_letters else "1234567890"
        kw = SCR_W / 10
        for i, ch in enumerate(toprow):
            d.rounded_rectangle((i * kw + 6, SCR_H - 520, (i + 1) * kw - 6, SCR_H - 410), radius=10, fill=WHITE)
            d.text((i * kw + kw / 2, SCR_H - 465), ch, font=font(34, False), fill=(20, 24, 32), anchor="mm")
        tg_on = (int(tl * 6) % 2 == 0)
        d.rounded_rectangle((20, SCR_H - 150, 230, SCR_H - 30), radius=12, fill=CORAL if tg_on else (170, 176, 186))
        d.text((125, SCR_H - 90), "123" if layout_letters else "ABC", font=font(40), fill=WHITE, anchor="mm")
        shake = int(8 * math.sin(tl * 60)) if err else 0
        dev = device(scr, scale=0.88, cx=W // 2 + shake, cy=H // 2 + 180)
        img.alpha_composite(dev)
        # kinetic stabs, stacked
        words = [("Numbers.", 0.15, WHITE), ("on iPhone.", 0.65, WHITE), ("ugh.", 1.4, CORAL)]
        dd = ImageDraw.Draw(img)
        for i, (wtxt, ws, col) in enumerate(words):
            if tl >= ws:
                p = eo_back((tl - ws) / 0.32)
                a = int(255 * clamp01(p))
                yoff = 96 + i * 116
                dd.text((72, yoff), wtxt, font=font(92), fill=col + (a,))
        if err:
            img = flash(img, tl - 2.5, color=CORAL, d=0.18)
        return img

    if name == "logo":
        img = bg(t, tint=BLUE, glow=0.8)
        d = ImageDraw.Draw(img)
        # keycaps fly in to form a numpad grid, then wordmark
        p = eo_back(tl / 0.8)
        gx, gy, cell = W // 2 - 150, 620, 100
        idx = 0
        for r in range(4):
            for c in range(3):
                if r == 3 and c != 1:
                    continue
                tx, ty = gx + c * cell, gy + r * cell
                off = (idx % 3 - 1) * lerp(500, 0, clamp01(p))
                a = int(255 * clamp01(tl / 0.6))
                bx = tx + off
                d.rounded_rectangle((bx, ty, bx + cell - 12, ty + cell - 12), radius=18, fill=BLUE + (a,))
                idx += 1
        if tl > 0.7:
            pp = eo_back((tl - 0.7) / 0.6)
            s = int(lerp(80, 150, clamp01(pp)))
            d.text((W / 2, 1120), "NumPad", font=font(s), fill=WHITE, anchor="mm")
        return flash(img, tl)

    if name in ("notes", "checkout", "sheet"):
        tint = {"notes": BLUE, "checkout": MINT, "sheet": VIOLET}[name]
        img = bg(t, tint=tint, glow=0.5)
        prog = eo_cubic(tl / (dur * 0.7))
        if name == "notes":
            scr = app_screen(host_notes(typed_number("1,248.90", prog)), theme="blue",
                             pressed=(int(tl * 8) % 3, int(tl * 5) % 3))
            cap = [("A real numpad.", False), ("In every app.", True)]
        elif name == "checkout":
            scr = app_screen(host_checkout(typed_number("4012 8888 8888", prog)), theme="blue",
                             pressed=(int(tl * 9) % 3, int(tl * 7) % 3))
            cap = [("Checkouts.", True)]
        else:
            scr = app_screen(host_sheet(typed_number("305", prog)), theme="blue",
                             pressed=(1, int(tl * 8) % 3))
            cap = [("Spreadsheets.", True)]
        img.alpha_composite(device(scr, scale=0.86, cy=360 + int(DEV_H * 0.86) // 2))
        img = caption(img, cap, tl, dur, accent=tint)
        img = light_sweep(img, (tl - 0.2) / 0.8)
        return flash(img, tl)

    if name == "taxtip":
        img = bg(t, tint=AMBER, glow=0.6)
        ov = eo_cubic(tl / 1.0)
        press = (3, 2) if tl < 0.4 else None  # press % conceptually
        scr = app_screen(host_notes("80.00", caret=False), theme="blue", overlay="taxtip", ov_prog=clamp01(tl / 0.8))
        img.alpha_composite(device(scr, scale=0.86, cy=360 + int(DEV_H * 0.86) // 2))
        img = caption(img, [("Tax & tip,", False), ("one long-press.", True)], tl, dur, accent=AMBER)
        if 0.9 < tl < 1.3:
            img = flash(img, tl - 0.9, color=MINT, d=0.18)  # confirm pop
        return flash(img, tl)

    if name == "clipboard":
        img = bg(t, tint=MINT, glow=0.6)
        pulled = 1 if tl > 1.8 else 0
        scr = app_screen(host_notes("1249-4912-4218" if tl > 2.2 else "", caret=True),
                         theme="blue", overlay="clipboard", ov_prog=clamp01(tl / 0.7), ov_pulled=pulled)
        img.alpha_composite(device(scr, scale=0.86, cy=360 + int(DEV_H * 0.86) // 2))
        img = caption(img, [("Recent numbers,", False), ("one tap.", True)], tl, dur, accent=MINT)
        return flash(img, tl)

    if name == "packs":
        img = bg(t, tint=VIOLET, glow=0.6)
        packs = [["$", "€", "£", "¥", "%"], ["@", "#", "&", "*", "="], ["0x", "&", "|", "^", "~"]]
        pk = packs[int(tl / 0.7) % len(packs)]
        scr = app_screen(host_notes("", caret=False), theme="violet", pack=pk)
        img.alpha_composite(device(scr, scale=0.86, cy=360 + int(DEV_H * 0.86) // 2))
        img = caption(img, [("Packs.", True)], tl, dur, accent=VIOLET)
        return flash(img, tl)

    if name == "themes":
        order = ["white", "indigo", "teal", "violet", "ink", "blue"]
        th = order[int(tl / 0.45) % len(order)]
        tint = {"white": BLUE, "indigo": (63, 81, 181), "teal": MINT, "violet": VIOLET, "ink": (90, 96, 110), "blue": BLUE}[th]
        img = bg(t, tint=tint if isinstance(tint, tuple) else BLUE, glow=0.7)
        scr = app_screen(host_notes("", caret=False), theme=th)
        img.alpha_composite(device(scr, scale=0.86, cy=360 + int(DEV_H * 0.86) // 2))
        img = caption(img, [("Themes.", True)], tl, dur, accent=tint if isinstance(tint, tuple) else BLUE)
        return flash(img, tl)

    if name == "ipad":
        img = bg(t, tint=BLUE, glow=0.7)
        # reuse the genuine iPad slide raw if present, else a wide device
        ipad = V.parents[0] / "raw" / "ipad" / "03-taxtip.png"
        if ipad.exists():
            slide = Image.open(ipad).convert("RGB")
            sc = int(lerp(1180, 1240, eo_cubic(tl / dur)))
            simg = slide.resize((sc, int(sc * slide.height / slide.width)), Image.LANCZOS)
            lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            # iPad frame
            fr = Image.new("RGBA", (simg.width + 60, simg.height + 60), (24, 26, 32, 255))
            ImageDraw.Draw(fr).rounded_rectangle((0, 0, fr.width, fr.height), radius=48, fill=(24, 26, 32, 255))
            m = Image.new("L", simg.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, simg.width, simg.height), radius=24, fill=255)
            fr.paste(simg, (30, 30), m)
            lay.alpha_composite(fr, (int(W / 2 - fr.width / 2), int(H / 2 - fr.height / 2 + 40)))
            img.alpha_composite(lay)
        img = caption(img, [("Built for iPad,", False), ("too.", True)], tl, dur, accent=BLUE)
        return flash(img, tl)

    # outro
    img = bg(t, tint=BLUE, glow=0.9)
    d = ImageDraw.Draw(img)
    p = eo_back(tl / 0.7)
    isz = int(lerp(160, 280, clamp01(p)))
    try:
        ic = Image.open(ICON).convert("RGBA").resize((isz, isz), Image.LANCZOS)
        m = Image.new("L", ic.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, isz, isz), radius=isz // 5, fill=255)
        img.paste(ic, (int(W / 2 - isz / 2), int(560 - isz / 2 + 120)), m)
    except OSError:
        pass
    if tl > 0.4:
        a = int(255 * clamp01((tl - 0.4) / 0.4))
        d.text((W / 2, 940), "NumPad", font=font(150), fill=WHITE + (a,), anchor="mm")
        d.text((W / 2, 1070), "Your number pad.", font=font(60, False), fill=(180, 200, 230, a), anchor="mm")
    if tl > 1.0:
        a = int(255 * clamp01((tl - 1.0) / 0.4))
        d.text((W / 2, 1200), "No subscription.", font=font(46), fill=MINT + (a,), anchor="mm")
        pill = (W / 2 - 300, 1300, W / 2 + 300, 1418)
        d.rounded_rectangle(pill, radius=58, fill=WHITE + (a,))
        d.text((W / 2, 1359), "Download on the App Store", font=font(42), fill=(16, 18, 26, a), anchor="mm")
    return flash(img, tl)


# ── drivers ──────────────────────────────────────────────────────────
def render_strip():
    n = 12
    ims = [render(TOTAL * (i + 0.5) / n).convert("RGB") for i in range(n)]
    tw, th = W // 6, H // 6
    sheet = Image.new("RGB", (tw * 6, th * 2), (255, 255, 255))
    for i, im in enumerate(ims):
        sheet.paste(im.resize((tw, th), Image.LANCZOS), ((i % 6) * tw, (i // 6) * th))
    sheet.save(OUT / "_commercial_strip.png")
    print("strip ->", OUT / "_commercial_strip.png")


def render_frames(a, b):
    CF.mkdir(parents=True, exist_ok=True)
    for f in range(a, b):
        render(f / FPS).convert("RGB").save(CF / f"f_{f:05d}.png")
    print(f"frames {a}-{b} done")


def encode():
    nf = int(TOTAL * FPS)
    # video from frames
    silent = OUT / "_commercial_silent.mp4"
    subprocess.run(["ffmpeg", "-y", "-framerate", str(FPS), "-i", str(CF / "f_%05d.png"),
                    "-frames:v", str(nf), "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                    "-pix_fmt", "yuv420p", str(silent)], check=True, capture_output=True)
    # audio mix (music + whooshes at scene cuts + a confirm at tax/tip)
    cuts, acc = [], 0.0
    for name, dur in SCENES[:-1]:
        acc += dur; cuts.append(acc)
    inp = ["-i", str(silent), "-i", str(V / "audio" / "music_bed.wav")]
    fc = [f"[1:a]atrim=0:{TOTAL:.2f},afade=t=out:st={TOTAL-1.2:.2f}:d=1.2,volume=0.9[m]"]
    labels = ["[m]"]; idx = 2
    for j, c in enumerate(cuts):
        ms = max(0, int(c * 1000 - 100))
        inp += ["-i", str(V / "audio" / "sfx_whoosh.wav")]
        fc.append(f"[{idx}:a]adelay={ms}|{ms},volume=0.45[w{j}]"); labels.append(f"[w{j}]"); idx += 1
    taxtip_start = sum(d for n, d in SCENES[:5]) + 1.0
    inp += ["-i", str(V / "audio" / "sfx_confirm.wav")]
    fc.append(f"[{idx}:a]adelay={int(taxtip_start*1000)}|{int(taxtip_start*1000)},volume=0.6[cf]"); labels.append("[cf]")
    fc.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95[a]")
    subprocess.run(["ffmpeg", "-y", *inp, "-filter_complex", ";".join(fc),
                    "-map", "0:v", "-map", "[a]", "-t", f"{TOTAL:.2f}",
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                    str(OUT / "commercial-master-portrait.mp4")], check=True, capture_output=True)
    # poster: the tax/tip total pop
    poster_t = sum(d for n, d in SCENES[:5]) + 1.2
    render(poster_t).convert("RGB").save(OUT / "poster-iphone.png")
    # cutdowns
    for name, T in [("social-15s.mp4", 15.0), ("social-6s.mp4", 6.0)]:
        subprocess.run(["ffmpeg", "-y", "-i", str(OUT / "commercial-master-portrait.mp4"), "-t", f"{T}",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "192k",
                        str(OUT / name)], check=True, capture_output=True)
    print("encode done:", TOTAL, "s")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    cmd = sys.argv[1] if len(sys.argv) > 1 else "plan"
    if cmd == "plan":
        acc = 0
        for n, dd in SCENES:
            print(f"  {acc:5.1f}-{acc+dd:5.1f}  {n}"); acc += dd
        print(f"  total {TOTAL:.1f}s = {int(TOTAL*FPS)} frames")
    elif cmd == "strip":
        render_strip()
    elif cmd == "frames":
        render_frames(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "encode":
        encode()
