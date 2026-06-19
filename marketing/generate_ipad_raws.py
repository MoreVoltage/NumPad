#!/usr/bin/env python3
"""Generate genuine iPad raw screenshots for the App Store marketing slides.

Unlike the iPhone raws (real Simulator captures) these iPad raws are rendered
from the app's actual iPad layout: the NumPad keyboard mounted in a host app
with the iPad-specific *side-panel* overlay layout (a 360pt trailing panel for
clipboard / tax-tip, shown when the keyboard width >= 700pt), plus pointer-hover
and drag affordances. Key glyphs, pack rows, theme colours and panel content all
match the Swift sources (Keyboard/Libraries/Item.swift, Views/*, SharedExtensions).

The raws are locale-independent — only numbers/symbols appear on the keys — so a
single set of six is generated and the localized marketing overlay is added later
by generate_app_store_screenshots.render_slide_ipad().

Output: marketing/raw/ipad/{slug}.png at 2048x2732 (iPad Pro 12.9"/13" portrait @2x).

    python3 marketing/generate_ipad_raws.py            # write the six raws
    python3 marketing/generate_ipad_raws.py --sheet     # also write a contact sheet
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "marketing" / "assets"
RAW = ROOT / "marketing" / "raw"
IPAD_RAW = RAW / "ipad"

# iPad Pro 12.9" portrait, @2x. (13" is 2064x2752; render_slide_ipad scales.)
RW, RH = 2048, 2732


# ── Fonts ────────────────────────────────────────────────────────────
def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf"
    try:
        return ImageFont.truetype(str(ASSETS / name), size)
    except OSError:
        return ImageFont.load_default()


# ── Theme palette (from SharedExtensions/Extensions color derivation) ─
# bg = keyboard background / inter-key separators (the gaps in grid mode)
# key = normal key fill, key2 = special-key fill (globe/back/return/space/slots)
# text = glyph colour, press = pressed/highlight fill (used for an active key)
THEMES = {
    "white": dict(bg=(230, 230, 230), key=(255, 255, 255), key2=(242, 242, 242),
                  text=(0, 0, 0), press=(206, 224, 255)),
    "black": dict(bg=(51, 51, 51), key=(26, 26, 26), key2=(38, 38, 38),
                  text=(255, 255, 255), press=(94, 94, 94)),
    "deepPurple": dict(bg=(126, 88, 197), key=(103, 58, 183), key2=(112, 68, 192),
                       text=(255, 255, 255), press=(169, 139, 221)),
    "teal": dict(bg=(26, 161, 148), key=(0, 150, 136), key2=(10, 162, 148),
                 text=(255, 255, 255), press=(120, 207, 198)),
}

# System side-panel chrome (systemBackground, light appearance)
PANEL_BG = (255, 255, 255)
PANEL_TITLE = (17, 24, 39)
PANEL_ROW = (28, 28, 30)
PANEL_SEC = (138, 138, 142)
PANEL_SEP = (210, 210, 214)
SYS_BLUE = (0, 122, 255)

# Host palette (neutral, matches recompose_overlay_raws.py)
HOST_BG = (255, 255, 255)
HOST_TITLE = (17, 24, 39)
HOST_LABEL = (100, 116, 139)
HOST_FIELD = (248, 250, 252)
HOST_FIELD_LINE = (226, 232, 240)
HOST_PLACEHOLDER = (148, 163, 184)


# ── Geometry ─────────────────────────────────────────────────────────
KB_H = 1040            # keyboard region height (px) ~ 520pt
KB_TOP = RH - KB_H
PANEL_W = 720          # 360pt @2x
PANEL_TRAIL = 20       # 10pt from trailing edge
PANEL_VPAD = 16        # 8pt top/bottom
PANEL_GAP = 14         # gap between grid and panel
PAD = 10               # outer grid padding
GAP = 6                # inter-key gap (grid mode)
PACK_H = 156           # pack-row height
KEY_R = 10             # subtle rounding for legibility (grid mode is square)


def rrect(d, box, radius, **kw):
    d.rounded_rectangle(box, radius=radius, **kw)


# ── Key icons (SF Symbols rendered as simple vector stand-ins) ───────
def icon_globe(d, cx, cy, r, color):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=5)
    d.line((cx, cy - r, cx, cy + r), fill=color, width=4)
    d.line((cx - r, cy, cx + r, cy), fill=color, width=4)
    d.ellipse((cx - r * 0.5, cy - r, cx + r * 0.5, cy + r), outline=color, width=4)
    d.line((cx - r * 0.92, cy - r * 0.45, cx + r * 0.92, cy - r * 0.45), fill=color, width=3)
    d.line((cx - r * 0.92, cy + r * 0.45, cx + r * 0.92, cy + r * 0.45), fill=color, width=3)


def icon_backspace(d, cx, cy, color):
    w, h = 76, 56
    notch = 30
    left = cx - w / 2
    top = cy - h / 2
    pts = [(left + notch, top), (left + w, top), (left + w, top + h),
           (left + notch, top + h), (left, cy)]
    d.polygon(pts, outline=color, width=5)
    xx = left + notch + 22
    d.line((xx, cy - 16, xx + 32, cy + 16), fill=color, width=5)
    d.line((xx, cy + 16, xx + 32, cy - 16), fill=color, width=5)


def icon_return(d, cx, cy, color):
    # corner arrow: down then left with an arrowhead
    d.line((cx + 34, cy - 26, cx + 34, cy + 12), fill=color, width=5)
    d.line((cx + 34, cy + 12, cx - 30, cy + 12), fill=color, width=5)
    d.line((cx - 30, cy + 12, cx - 8, cy - 8), fill=color, width=5)
    d.line((cx - 30, cy + 12, cx - 8, cy + 32), fill=color, width=5)


# ── Key drawing ──────────────────────────────────────────────────────
def draw_key(d, box, theme, *, label=None, kind="num", active=False, locked=False):
    """kind: num | special | pack"""
    fill = theme["key"]
    if kind in ("special", "pack"):
        fill = theme["key2"]
    if active:
        fill = theme["press"]
    rrect(d, box, KEY_R, fill=fill)
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    tcolor = theme["text"]
    if label in ("__globe__", "__back__", "__return__"):
        if label == "__globe__":
            icon_globe(d, cx, cy, 30, tcolor)
        elif label == "__back__":
            icon_backspace(d, cx, cy, tcolor)
        else:
            icon_return(d, cx, cy, tcolor)
    elif label is not None:
        sz = 54 if kind == "pack" else 64
        if label in ("space",):
            sz = 40
        f = font(sz, bold=False)
        d.text((cx, cy - 4), label, font=f, fill=tcolor, anchor="mm")
    if locked:
        # lock.fill top-right + "Unlock" tooltip (StackView.swift)
        lx, ly = x1 - 26, y0 + 20
        lc = tuple(list(tcolor) )
        d.rounded_rectangle((lx - 12, ly - 8, lx + 12, ly + 14), radius=4, fill=tcolor)
        d.rectangle((lx - 8, ly - 2, lx + 8, ly + 14), fill=fill)
        d.rounded_rectangle((lx - 8, ly + 1, lx + 8, ly + 14), radius=3, fill=tcolor)
        d.arc((lx - 7, ly - 12, lx + 7, ly + 6), 180, 360, fill=tcolor, width=3)


# ── Keyboard region ──────────────────────────────────────────────────
def draw_keyboard(base, theme_name, *, pack=None, panel=None, active_key=None,
                  locked_pack=False):
    theme = THEMES[theme_name]
    d = ImageDraw.Draw(base, "RGBA")
    # keyboard background plate
    d.rectangle((0, KB_TOP, RW, RH), fill=theme["bg"])

    grid_right = RW
    if panel is not None:
        panel_x0 = RW - PANEL_TRAIL - PANEL_W
        grid_right = panel_x0 - PANEL_GAP
        panel_box = (panel_x0, KB_TOP + PANEL_VPAD, RW - PANEL_TRAIL, RH - PANEL_VPAD)
        draw_panel(d, panel_box, panel)

    gx0 = PAD
    gx1 = grid_right - PAD
    gy0 = KB_TOP + PAD
    gy1 = RH - PAD

    rows_y0 = gy0
    if pack is not None:
        draw_pack_row(d, (gx0, gy0, gx1, gy0 + PACK_H), theme, pack, locked=locked_pack)
        rows_y0 = gy0 + PACK_H + GAP

    col_w = (gx1 - gx0 - 3 * GAP) / 4
    row_h = (gy1 - rows_y0 - 3 * GAP) / 4

    def cell(c, r, span=1):
        x0 = gx0 + c * (col_w + GAP)
        y0 = rows_y0 + r * (row_h + GAP)
        x1 = x0 + col_w * span + GAP * (span - 1)
        y1 = y0 + row_h
        return (x0, y0, x1, y1)

    layout = [
        [("1", "num"), ("2", "num"), ("3", "num"), (",", "special")],
        [("4", "num"), ("5", "num"), ("6", "num"), (".", "special")],
        [("7", "num"), ("8", "num"), ("9", "num"), ("space", "special")],
        [("__globe__", "special"), ("0", "num"), ("__back__", "special"), ("__return__", "special")],
    ]
    for r, row in enumerate(layout):
        for c, (label, kind) in enumerate(row):
            draw_key(d, cell(c, r), theme, label=label, kind=kind,
                     active=(active_key == (r, c)))


def draw_pack_row(d, box, theme, glyphs, locked=False):
    x0, y0, x1, y1 = box
    n = len(glyphs)
    gap = GAP
    kw = (x1 - x0 - gap * (n - 1)) / n
    for i, g in enumerate(glyphs):
        kx0 = x0 + i * (kw + gap)
        draw_key(d, (kx0, y0, kx0 + kw, y1), theme, label=g, kind="pack",
                 locked=(locked and i == 0))


# ── Side panels ──────────────────────────────────────────────────────
def panel_header(d, box, title, *, left=None, right="Close"):
    x0, y0, x1, y1 = box
    rrect(d, box, 24, fill=PANEL_BG)
    d.text(((x0 + x1) / 2, y0 + 44, ), title, font=font(34, bold=True),
           fill=PANEL_TITLE, anchor="mm")
    if right:
        d.text((x1 - 28, y0 + 44), right, font=font(30), fill=SYS_BLUE, anchor="rm")
    if left:
        d.text((x0 + 28, y0 + 44), left, font=font(30), fill=SYS_BLUE, anchor="lm")
    return y0 + 92


def draw_panel(d, box, kind):
    if kind == "clipboard":
        panel_clipboard(d, box)
    elif kind == "taxtip":
        panel_taxtip(d, box)
    elif kind == "snippets":
        panel_snippets(d, box)


def panel_clipboard(d, box):
    x0, y0, x1, y1 = box
    y = panel_header(d, box, "Clipboard History", left="Clear All")
    rows = [("1,249.99", True), ("555-867-5309", False), ("1249-4912-4218", False),
            ("$80.00", False), ("4012 8888 8888 1881", False), ("18.5%", False)]
    rh = 92
    for text, pinned in rows:
        d.line((x0 + 24, y, x1 - 24, y), fill=PANEL_SEP, width=2)
        d.text((x0 + 30, y + rh / 2), text, font=font(32), fill=PANEL_ROW, anchor="lm")
        if pinned:
            # pin.fill stand-in
            px, py = x1 - 44, y + rh / 2
            d.ellipse((px - 9, py - 18, px + 9, py - 2), fill=PANEL_SEC)
            d.line((px, py - 2, px, py + 16), fill=PANEL_SEC, width=5)
        y += rh


def panel_taxtip(d, box):
    x0, y0, x1, y1 = box
    y = panel_header(d, box, "TAX / TIP", right="Close")
    pad = 30
    y += 16
    # Amount field
    rrect(d, (x0 + pad, y, x1 - pad, y + 84), 16, fill=HOST_FIELD, outline=HOST_FIELD_LINE, width=2)
    d.text((x0 + pad + 22, y + 42), "80.00", font=font(34, bold=True), fill=PANEL_ROW, anchor="lm")
    d.text((x1 - pad - 22, y + 42), "Amount", font=font(26), fill=PANEL_SEC, anchor="rm")
    y += 84 + 30

    def seg(label, options, sel, yy):
        d.text((x0 + pad, yy + 30), label, font=font(28), fill=PANEL_SEC, anchor="lm")
        sx0 = x0 + pad + 120
        sw = (x1 - pad - sx0) / len(options)
        for i, opt in enumerate(options):
            bx0 = sx0 + i * sw
            box_ = (bx0 + 4, yy, bx0 + sw - 4, yy + 60)
            if i == sel:
                rrect(d, box_, 12, fill=SYS_BLUE)
                d.text(((box_[0] + box_[2]) / 2, yy + 30), opt, font=font(26, bold=True),
                       fill=(255, 255, 255), anchor="mm")
            else:
                rrect(d, box_, 12, outline=PANEL_SEP, width=2)
                d.text(((box_[0] + box_[2]) / 2, yy + 30), opt, font=font(26),
                       fill=PANEL_ROW, anchor="mm")
        return yy + 60 + 24

    y = seg("Tax", ["0", "5", "8", "10", "13", "15"], 2, y)
    y = seg("Tip", ["0", "10", "15", "18", "20", "25"], 3, y)
    y += 6
    # result
    rrect(d, (x0 + pad, y, x1 - pad, y + 96), 16, fill=(240, 247, 240))
    d.text((x0 + pad + 22, y + 48), "Total", font=font(30), fill=PANEL_SEC, anchor="lm")
    d.text((x1 - pad - 22, y + 48), "$97.20", font=font(40, bold=True), fill=(20, 120, 60), anchor="rm")
    y += 96 + 24
    # Insert button
    rrect(d, (x0 + pad, y, x1 - pad, y + 84), 16, fill=SYS_BLUE)
    d.text(((x0 + x1) / 2, y + 42), "Insert", font=font(32, bold=True), fill=(255, 255, 255), anchor="mm")


def panel_snippets(d, box):
    x0, y0, x1, y1 = box
    y = panel_header(d, box, "Snippets", left="+")
    rows = ["Invoice {date}", "Net 30 terms", "Total due:", "Account #4912", "+1 (555) 867-5309"]
    rh = 100
    for text in rows:
        d.line((x0 + 24, y, x1 - 24, y), fill=PANEL_SEP, width=2)
        d.text((x0 + 30, y + rh / 2), text, font=font(32), fill=PANEL_ROW, anchor="lm")
        y += rh


# ── Status bar + hosts ───────────────────────────────────────────────
def draw_status_bar(d, dark=False):
    col = (235, 235, 235) if dark else (17, 24, 39)
    d.text((58, 50), "9:41", font=font(38, bold=True), fill=col)
    # right cluster: wifi + battery
    bx = RW - 150
    d.rounded_rectangle((bx, 44, bx + 84, 80), radius=10, outline=col, width=4)
    d.rounded_rectangle((bx + 6, 50, bx + 64, 74), radius=5, fill=col)
    d.rounded_rectangle((bx + 88, 54, bx + 96, 70), radius=3, fill=col)


def host_notes(base, title, rows, accent=SYS_BLUE, field_label="Type with NumPad here"):
    d = ImageDraw.Draw(base, "RGBA")
    d.rectangle((0, 0, RW, KB_TOP), fill=HOST_BG)
    draw_status_bar(d)
    d.text((70, 150), "Notes", font=font(40, bold=True), fill=accent)
    d.text((70, 230), title, font=font(72, bold=True), fill=HOST_TITLE)
    d.rounded_rectangle((68, 340, RW - 68, 356), radius=8, fill=(238, 242, 247))
    y = 470
    for label, value in rows:
        d.text((92, y), label, font=font(40), fill=HOST_LABEL)
        d.text((620, y), value, font=font(48, bold=True), fill=HOST_TITLE)
        y += 150
    field_top = max(y + 30, KB_TOP - 360)
    d.rounded_rectangle((84, field_top, RW - 84, field_top + 230), radius=24,
                        fill=HOST_FIELD, outline=HOST_FIELD_LINE, width=2)
    d.text((124, field_top + 86), field_label, font=font(40), fill=HOST_PLACEHOLDER)
    d.rounded_rectangle((114, field_top + 88, 119, field_top + 150), radius=2, fill=accent)


def host_checkout(base, accent=SYS_BLUE):
    d = ImageDraw.Draw(base, "RGBA")
    d.rectangle((0, 0, RW, KB_TOP), fill=(247, 248, 250))
    draw_status_bar(d)
    d.text((RW / 2, 150), "Checkout", font=font(44, bold=True), fill=HOST_TITLE, anchor="mm")
    card = (96, 250, RW - 96, KB_TOP - 120)
    d.rounded_rectangle(card, radius=28, fill=(255, 255, 255), outline=(232, 236, 242), width=2)

    def field(label, value, yy, active=False):
        d.text((150, yy), label, font=font(34), fill=HOST_LABEL)
        box = (150, yy + 50, RW - 150, yy + 140)
        d.rounded_rectangle(box, radius=18, fill=HOST_FIELD,
                            outline=(accent if active else HOST_FIELD_LINE), width=3 if active else 2)
        d.text((180, yy + 95), value, font=font(44, bold=True), fill=HOST_TITLE, anchor="lm")
        return yy + 200

    y = 330
    y = field("Card number", "4012 8888 8888 1881", y, active=True)
    half = (RW - 150 - 150 - 40) / 2
    d.text((150, y), "Expiry", font=font(34), fill=HOST_LABEL)
    d.rounded_rectangle((150, y + 50, 150 + half, y + 140), radius=18, fill=HOST_FIELD, outline=HOST_FIELD_LINE, width=2)
    d.text((180, y + 95), "09 / 27", font=font(44, bold=True), fill=HOST_TITLE, anchor="lm")
    d.text((150 + half + 40, y), "CVV", font=font(34), fill=HOST_LABEL)
    d.rounded_rectangle((150 + half + 40, y + 50, RW - 150, y + 140), radius=18, fill=HOST_FIELD, outline=HOST_FIELD_LINE, width=2)
    d.text((180 + half + 40, y + 95), "• • •", font=font(44, bold=True), fill=HOST_TITLE, anchor="lm")
    y += 210
    d.line((150, y, RW - 150, y), fill=(238, 242, 247), width=3)
    y += 50
    d.text((150, y), "Total", font=font(40), fill=HOST_LABEL)
    d.text((RW - 150, y), "$129.00", font=font(56, bold=True), fill=HOST_TITLE, anchor="ra")


def host_code(base):
    d = ImageDraw.Draw(base, "RGBA")
    d.rectangle((0, 0, RW, KB_TOP), fill=(13, 17, 23))
    draw_status_bar(d, dark=True)
    d.text((70, 150), "main.swift", font=font(38, bold=True), fill=(139, 148, 158))
    d.rounded_rectangle((68, 230, RW - 68, 246), radius=8, fill=(33, 38, 45))
    lines = [
        [("let ", (255, 123, 114)), ("mask", (121, 192, 255)), (" = ", (201, 209, 217)), ("0xFF00", (255, 199, 119))],
        [("let ", (255, 123, 114)), ("flags", (121, 192, 255)), (" = ", (201, 209, 217)), ("a << ", (201, 209, 217)), ("3", (255, 199, 119))],
        [("total", (121, 192, 255)), (" += ", (201, 209, 217)), ("items", (201, 209, 217)), (" * ", (201, 209, 217)), ("1.08", (255, 199, 119))],
        [("price", (121, 192, 255)), (" = ", (201, 209, 217)), ("(net) ", (201, 209, 217)), ("& ", (255, 123, 114)), ("0x7F", (255, 199, 119))],
    ]
    y = 320
    for i, parts in enumerate(lines):
        d.text((84, y), str(i + 1), font=font(34), fill=(72, 79, 88))
        x = 180
        for txt, col in parts:
            d.text((x, y), txt, font=font(40), fill=col)
            x += d.textlength(txt, font=font(40))
        y += 110
    # caret line
    d.rounded_rectangle((180, y + 8, 185, y + 64), radius=2, fill=(201, 209, 217))


def host_themes(base):
    d = ImageDraw.Draw(base, "RGBA")
    d.rectangle((0, 0, RW, KB_TOP), fill=(250, 250, 252))
    draw_status_bar(d)
    d.text((RW / 2, 150), "Themes", font=font(44, bold=True), fill=HOST_TITLE, anchor="mm")
    swatches = [
        ("White", (255, 255, 255), (200, 200, 200)),
        ("Indigo", (63, 81, 181), (63, 81, 181)),
        ("Teal", (0, 150, 136), (0, 150, 136)),
        ("Deep Purple", (103, 58, 183), (103, 58, 183)),
        ("Black", (26, 26, 26), (26, 26, 26)),
        ("Deep Orange", (255, 87, 34), (255, 87, 34)),
    ]
    cols = 3
    sw = (RW - 200 - 60 * (cols - 1)) / cols
    sh = 280
    x0, y0 = 100, 280
    for i, (name, fill, ring) in enumerate(swatches):
        r, c = divmod(i, cols)
        bx = x0 + c * (sw + 60)
        by = y0 + r * (sh + 60)
        sel = (i == 3)
        d.rounded_rectangle((bx, by, bx + sw, by + sh), radius=28, fill=fill,
                            outline=(SYS_BLUE if sel else (230, 232, 236)), width=8 if sel else 2)
        tcol = (17, 24, 39) if fill == (255, 255, 255) else (255, 255, 255)
        d.text((bx + sw / 2, by + sh - 50), name, font=font(34, bold=True), fill=tcol, anchor="mm")
        if sel:
            d.ellipse((bx + sw - 70, by + 30, bx + sw - 20, by + 80), fill=SYS_BLUE)
            d.line((bx + sw - 58, by + 55, bx + sw - 47, by + 66), fill=(255, 255, 255), width=5)
            d.line((bx + sw - 47, by + 66, bx + sw - 30, by + 42), fill=(255, 255, 255), width=5)


# ── Slides ───────────────────────────────────────────────────────────
def build(slug):
    base = Image.new("RGBA", (RW, RH), (255, 255, 255, 255))
    if slug == "01-hero":
        host_notes(base, "Quarterly numbers",
                   [("Revenue", "1,248,900.00"), ("Units sold", "48,210"), ("Growth", "12.4%")])
        draw_keyboard(base, "white", active_key=(1, 1))
    elif slug == "02-checkout":
        host_checkout(base)
        draw_keyboard(base, "white", active_key=(2, 1))
    elif slug == "03-taxtip":
        host_notes(base, "Dinner total",
                   [("Subtotal", "$80.00"), ("Tax", "8%"), ("Tip", "18%"), ("Total", "$97.20")])
        draw_keyboard(base, "white", panel="taxtip")
    elif slug == "04-clipboard":
        host_notes(base, "Invoice notes",
                   [("Invoice", "1,249.99"), ("Phone", "555-867-5309"), ("Order", "1249-4912-4218")])
        draw_keyboard(base, "white", panel="clipboard")
    elif slug == "05-packs":
        host_code(base)
        draw_keyboard(base, "black",
                      pack=["0x", "&", "|", "^", "~", "<<", ">>", "(", ")", ";"],
                      panel="snippets")
    elif slug == "06-themes":
        host_themes(base)
        draw_keyboard(base, "deepPurple")
    else:
        raise ValueError(slug)
    return base.convert("RGB")


SLUGS = ["01-hero", "02-checkout", "03-taxtip", "04-clipboard", "05-packs", "06-themes"]


def main():
    IPAD_RAW.mkdir(parents=True, exist_ok=True)
    imgs = []
    for slug in SLUGS:
        img = build(slug)
        out = IPAD_RAW / f"{slug}.png"
        img.save(out, optimize=True)
        imgs.append(img)
        print(f"  wrote {out.relative_to(ROOT)}  {img.size}")
    if "--sheet" in sys.argv:
        cols = 6
        tw, th = RW // 5, RH // 5
        sheet = Image.new("RGB", (tw * cols, th), (245, 245, 245))
        for i, img in enumerate(imgs):
            sheet.paste(img.resize((tw, th), Image.Resampling.LANCZOS), (i * tw, 0))
        sheet.save(IPAD_RAW / "_contact_sheet.png")
        print(f"  wrote {(IPAD_RAW / '_contact_sheet.png').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
