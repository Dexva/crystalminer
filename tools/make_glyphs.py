"""Glyph textures, glyph metrics and backgrounds for the in-game signs.

Lettering is rendered from DejaVu Sans, DejaVu Sans Bold and DejaVu Sans Condensed Bold (Bitstream
Vera / DejaVu licence: free to use and redistribute; see LICENSE.fonts). The fonts are proportional,
so besides one PNG per character this writes mods/crystalminer/sign_metrics.lua: for every glyph
set its line height and, per character, the advance width and the x offset of its image. The
layout in signs.lua reads those numbers.

Glyph sets, each in one ink (name: font, px size, line height, tracking, ink):
  b52 c44     banner titles (bold; condensed bold when the title is long)
  b34         board titles, lever-label letters
  b26         panel and plaque titles
  b17         meta lines ("## Symmetry m-3m · tier 3") in the accent colour
  r24         banner subtitles (muted)
  r20 r18 r16 body text (r18 and r16 also as smaller fallbacks when a text is long)
Files: crystalminer_<set>_<code>.png, e.g. crystalminer_r20_101.png. The image is cropped to the
ink horizontally and is as tall as the font (ascent + descent).

Backgrounds: crystalminer_sign_<format>_<height>.png, warm paper with a thin edge and a teal accent
bar, one per allowed height (heights are multiples of 32 px, 0.25 node at 128 px per node); a
72 x 4 rule under board titles; 8 x 32 bar tiles in the tier colours for portal plaques.
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(HERE, "..", "mods", "crystalminer")
OUT = os.path.join(MOD, "textures")
FD = "/usr/share/fonts/truetype/dejavu/"
FONTS = {"r": FD + "DejaVuSans.ttf", "b": FD + "DejaVuSans-Bold.ttf", "c": FD + "DejaVuSansCondensed-Bold.ttf"}

# Palette "Paper".
PAPER, EDGE = (245, 240, 230), (189, 176, 154)              # #F5F0E6, #BDB09A
TITLE, BODY, MUTED = (30, 34, 39), (48, 52, 58), (88, 93, 102)  # #1E2227, #30343A, #585D66
ACCENT = (27, 107, 116)                                      # #1B6B74
TIERS = {1: (86, 182, 223), 2: (119, 190, 76), 3: (228, 142, 38), 4: (190, 85, 190)}  # border_<tier>

# name: (font, px, line height, tracking, ink)
SETS = {
    "b52": ("b", 52, 60, 2, TITLE), "c44": ("c", 44, 50, 1, TITLE),
    "b34": ("b", 34, 42, 0, TITLE), "b26": ("b", 26, 33, 0, TITLE),
    "b17": ("b", 17, 24, 0, ACCENT), "r24": ("r", 24, 30, 0, MUTED),
    "r20": ("r", 20, 29, 0, BODY), "r18": ("r", 18, 25, 0, BODY), "r16": ("r", 16, 22, 0, BODY),
}
# Printable ASCII, the accented letters and symbols in the texts, curly quotes and the minus sign
# (the layout turns ' into ‘ or ’, and a hyphen before a digit, as in m-3m, into a minus).
CODES = list(range(32, 127)) + [ord(c) for c in "üéöäÅåøàè°·–—‘’₁₂₃₄−"]

# Background heights per format, in px (128 px per node). No sign is larger than before the
# redesign: plaque 384 x 192, panel 576 x 384, board 768 x 576, banner 768 x 192, label 192 x 96.
HEIGHTS = {
    "board": (768, range(256, 577, 32)), "panel": (576, range(192, 385, 32)),
    "plaque": (384, range(128, 193, 32)), "banner": (768, range(160, 193, 32)), "label": (192, [96]),
}
EDGE_W, BAR = 3, {"board": ("top", 10), "panel": ("left", 8), "plaque": ("left", 8),
                  "banner": ("bottom", 8), "label": ("bottom", 6)}


def glyph(font, size, ch_code, ink):
    """(image or None, advance, x offset): the glyph cropped to its ink, full font height."""
    f = ImageFont.truetype(FONTS[font], size)
    asc, desc = f.getmetrics()
    h = asc + desc
    if ch_code in (45, 8722):
        # A hyphen at least 2 px thick, so it survives being seen from a few steps away; the minus
        # (m-3m, -4) a wider and bolder bar at the height of the hyphen.
        adv = f.getlength("-") if ch_code == 45 else f.getlength("+") * 0.8
        th = max(2, round(size * (0.085 if ch_code == 45 else 0.13)))
        bw = round(adv * (0.62 if ch_code == 45 else 0.86))
        yc = asc - round(size * 0.33)
        mask = Image.new("L", (bw, h), 0)
        ImageDraw.Draw(mask).rectangle((0, yc - th // 2, bw - 1, yc - th // 2 + th - 1), fill=255)
        xoff = round((adv - bw) / 2)
    else:
        ch = chr(ch_code)
        adv = f.getlength(ch)
        pad = size
        mask = Image.new("L", (int(adv) + 2 * pad, h), 0)
        ImageDraw.Draw(mask).text((pad, asc), ch, font=f, fill=255, anchor="ls")
        bb = mask.getbbox()
        if bb is None:
            return None, adv, 0, h
        mask = mask.crop((bb[0], 0, bb[2], h))
        xoff = bb[0] - pad
    img = Image.new("RGBA", mask.size, ink + (0,))
    img.putalpha(mask)
    return img, adv, xoff, h


def background(fmt, w, h):
    img = Image.new("RGBA", (w, h), EDGE + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle((EDGE_W, EDGE_W, w - EDGE_W - 1, h - EDGE_W - 1), fill=PAPER + (255,))
    side, bw = BAR[fmt]
    box = {"top": (0, 0, w - 1, bw - 1), "left": (0, 0, bw - 1, h - 1), "bottom": (0, h - bw, w - 1, h - 1)}[side]
    d.rectangle(box, fill=ACCENT + (255,))
    return img


def main():
    lua = ["-- Generated by tools/make_glyphs.py: do not edit. Glyph metrics for the sign lettering.",
           "-- Per set: line height, image height, tracking; per code point: advance (px) and x offset.",
           "return {"]
    files = 0
    for name, (font, size, lh, track, ink) in SETS.items():
        adv, xoff, height = [], [], 0
        for code in CODES:
            img, a, x, height = glyph(font, size, code, ink)
            adv.append("[%d]=%s" % (code, ("%.2f" % a).rstrip("0").rstrip(".")))
            if img is not None:
                xoff.append("[%d]=%d" % (code, x))
                img.save(os.path.join(OUT, "crystalminer_%s_%d.png" % (name, code)), optimize=True)
                files += 1
        lua.append("\t%s = { lh = %d, h = %d, track = %d," % (name, lh, height, track))
        lua.append("\t\tadv = { " + ", ".join(adv) + " },")
        lua.append("\t\txoff = { " + ", ".join(xoff) + " } },")
    lua.append("}")
    with open(os.path.join(MOD, "sign_metrics.lua"), "w") as f:
        f.write("\n".join(lua) + "\n")
    bgs = 0
    for fmt, (w, hs) in HEIGHTS.items():
        for h in hs:
            background(fmt, w, h).save(os.path.join(OUT, "crystalminer_sign_%s_%d.png" % (fmt, h)), optimize=True)
            bgs += 1
    Image.new("RGBA", (72, 4), ACCENT + (255,)).save(os.path.join(OUT, "crystalminer_sign_rule.png"), optimize=True)
    for t, col in TIERS.items():
        Image.new("RGBA", (8, 32), col + (255,)).save(os.path.join(OUT, "crystalminer_sign_bar_%d.png" % t), optimize=True)
    print(files, "glyphs in", len(SETS), "sets,", bgs, "backgrounds, 1 rule,", len(TIERS), "tier bars")


if __name__ == "__main__":
    main()
