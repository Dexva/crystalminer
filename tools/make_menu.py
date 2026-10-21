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


def make_header():
    W, H = 800, 200
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4 * SS, 4 * SS, (W - 4) * SS, (H - 4) * SS], radius=22 * SS,
                        fill=CREAM, outline=INK, width=3 * SS)
    cube(d, 100 * SS, H * SS / 2, 60 * SS)
    mirror_line(d, 100 * SS, 14 * SS, (H - 14) * SS, 6 * SS, 2 * SS)
    d.rectangle([200 * SS, 128 * SS, 480 * SS, 133 * SS], fill=YELLOW)
    d.rectangle([480 * SS, 128 * SS, 760 * SS, 133 * SS], fill=BLUE)
    title = ImageFont.truetype(FONTDIR + "DejaVuSans-Bold.ttf", 64 * SS)
    sub = ImageFont.truetype(FONTDIR + "DejaVuSans.ttf", 24 * SS)
    d.text((200 * SS, 40 * SS), "crystalminer", font=title, fill=INK)
    d.text((200 * SS, 146 * SS), "Symmetry and crystals, block by block", font=sub, fill=INK)
    return im.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_icon().save(os.path.join(OUT, "icon.png"))
    make_header().save(os.path.join(OUT, "header.png"))
    print("wrote", os.path.normpath(OUT))
