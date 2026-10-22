#!/usr/bin/env python3
"""Generate the Luanti main-menu images for crystalminer into menu/.

Luanti reads menu/icon.png (game icon; src/script/lua_api/l_mainmenu.cpp) and
menu/header.png (menu images named $identifier.png; doc/lua_api.md, "Menu images").
Run:  python3 tools/make_menu.py   (needs Pillow and the DejaVu fonts)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

YELLOW = (248, 197, 39)
BLUE = (58, 120, 217)
CREAM = (250, 246, 236)
INK = (40, 36, 30)
FONTDIR = "/usr/share/fonts/truetype/dejavu/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "menu")
SS = 4  # supersampling factor


def cube(d, cx, cy, r):
    """Isometric cube: left face yellow, right face blue, top cream.
    The mirror plane is the vertical line through cx."""
    dx, dy = r * math.cos(math.radians(30)), r * 0.5
    top, bot = (cx, cy - r), (cx, cy + r)
    ur, lr = (cx + dx, cy - dy), (cx + dx, cy + dy)
    ll, ul = (cx - dx, cy + dy), (cx - dx, cy - dy)
    ctr = (cx, cy)
    w = max(2, int(r * 0.06))
    faces = [([top, ur, ctr, ul], CREAM), ([ul, ctr, bot, ll], YELLOW),
             ([ctr, ur, lr, bot], BLUE)]
    for poly, col in faces:
        d.polygon(poly, fill=col)
    for poly, _ in faces:
        d.line(poly + [poly[0]], fill=INK, width=w, joint="curve")


def mirror_line(d, x, y0, y1, dash, w):
    y = y0
    while y < y1:
        d.line([(x, y), (x, min(y + dash, y1))], fill=INK, width=w)
        y += dash * 2


def make_icon():
    n = 128 * SS
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4 * SS, 4 * SS, n - 4 * SS, n - 4 * SS], radius=18 * SS,
                        fill=CREAM, outline=INK, width=3 * SS)
    cube(d, n / 2, n / 2 + 2 * SS, 40 * SS)
    mirror_line(d, n / 2, 10 * SS, n - 10 * SS, 5 * SS, int(1.5 * SS))
    return im.resize((128, 128), Image.LANCZOS)


GLYPHS = {
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    ",": [".....", ".....", ".....", ".....", "..##.", "..##.", "..#.."],
    " ": ["...", "...", "...", "...", "...", "...", "..."],
}
# crystal palette: (top colour, bottom colour) per title letter
AMETHYST = ((214, 140, 255), (128, 66, 214))
SAPPHIRE = ((120, 190, 255), (48, 94, 214))
TEAL = ((110, 240, 232), (24, 150, 170))
EMERALD = ((140, 255, 160), (30, 160, 90))
GOLD = ((255, 232, 120), (240, 150, 30))
ROSE = ((255, 160, 200), (214, 70, 130))
TITLE_PAL = [AMETHYST, SAPPHIRE, TEAL, EMERALD, GOLD, ROSE] * 2
NAVY = (14, 18, 48)
PANEL_EDGE = (120, 110, 220)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def text_width(text, scale):
    return sum(len(GLYPHS[ch][0]) for ch in text) * scale + (len(text) - 1) * scale


def draw_text(d, x, y, text, scale, palette, shadow=1, bevel=0):
    """Draw text in blocks of scale x scale px; palette is a function
    (letter_index) -> (top, bottom) colours blended down the glyph rows."""
    # pass 1: shadow, pass 2: letters
    for layer in ("shadow", "face"):
        cx = x
        li = 0
        for ch in text:
            g = GLYPHS[ch]
            top, bot = palette(li)
            for r, row in enumerate(g):
                for c, v in enumerate(row):
                    if v != "#":
                        continue
                    col = lerp(top, bot, r / 6.0)
                    px, py = cx + c * scale, y + r * scale
                    if layer == "shadow":
                        d.rectangle([px + shadow, py + shadow,
                                     px + scale - 1 + shadow, py + scale - 1 + shadow],
                                    fill=shade(col, 0.28))
                    else:
                        d.rectangle([px, py, px + scale - 1, py + scale - 1], fill=col)
                        if bevel:
                            d.rectangle([px, py, px + scale - 1, py + bevel - 1],
                                        fill=shade(col, 1.25))
                            d.rectangle([px, py + scale - bevel, px + scale - 1, py + scale - 1],
                                        fill=shade(col, 0.72))
            cx += (len(g[0]) + 1) * scale
            if ch != " ":
                li += 1 if layer == "face" or True else 0
            else:
                pass
    return d


def sparkle(d, cx, cy, r, col):
    d.rectangle([cx - r, cy, cx + r, cy], fill=col)
    d.rectangle([cx, cy - r, cx, cy + r], fill=col)
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=col)


def make_header():
    W, H = 800, 200
    big = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    bd = ImageDraw.Draw(big)
    bd.rounded_rectangle([4 * SS, 4 * SS, (W - 4) * SS, (H - 4) * SS], radius=22 * SS,
                         fill=NAVY, outline=PANEL_EDGE, width=3 * SS)
    im = big.resize((W, H), Image.LANCZOS)
    # faint pixel grid, clipped to the panel
    grid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for gx in range(0, W, 20):
        gd.line([(gx, 0), (gx, H)], fill=(80, 90, 190, 34))
    for gy in range(0, H, 20):
        gd.line([(0, gy), (W, gy)], fill=(80, 90, 190, 34))
    mask = im.getchannel("A").point(lambda v: 255 if v > 250 else 0)
    inner = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    inner.paste(grid, (0, 0), mask)
    im = Image.alpha_composite(im, inner)
    d = ImageDraw.Draw(im)

    ts, ss_ = 10, 3
    title, sub = "CRYSTALMINER", "SYMMETRY AND CRYSTALS, BLOCK BY BLOCK"
    tx = (W - text_width(title, ts)) // 2
    draw_text(d, tx, 34, title, ts, lambda i: TITLE_PAL[i], shadow=4, bevel=2)
    # gradient rule under the title
    y0 = 34 + 7 * ts + 14
    x0, x1 = tx, tx + text_width(title, ts)
    for x in range(x0, x1, 4):
        t = (x - x0) / (x1 - x0)
        stops = [AMETHYST[0], SAPPHIRE[0], TEAL[0], EMERALD[0], GOLD[0], ROSE[0]]
        k = min(int(t * 5), 4)
        col = lerp(stops[k], stops[k + 1], t * 5 - k)
        d.rectangle([x, y0, x + 3, y0 + 3], fill=col)
    sx = (W - text_width(sub, ss_)) // 2
    n = len(sub.replace(" ", ""))
    cols = [AMETHYST[0], SAPPHIRE[0], TEAL[0], EMERALD[0], GOLD[0], ROSE[0]]
    def subpal(i):
        t = i / max(1, n - 1) * 5
        k = min(int(t), 4)
        c = lerp(cols[k], cols[k + 1], t - k)
        return (c, shade(c, 0.8))
    draw_text(d, sx, y0 + 18, sub, ss_, subpal, shadow=2)
    # pixel sparkles (no figure)
    for (cx, cy, r, c) in [(34, 36, 6, (255, 232, 120)), (772, 160, 6, (110, 240, 232)),
                           (752, 34, 4, (214, 140, 255)), (48, 164, 4, (140, 255, 160)),
                           (26, 100, 3, (120, 190, 255)), (776, 96, 3, (255, 160, 200))]:
        sparkle(d, cx, cy, r, c)
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_icon().save(os.path.join(OUT, "icon.png"))
    make_header().save(os.path.join(OUT, "header.png"))
    print("wrote", os.path.normpath(OUT))
