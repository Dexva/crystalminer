"""Glyph textures for in-game signs, rendered from DejaVu Sans Mono (Bitstream Vera / DejaVu
licence: free to use and redistribute), and the sign backgrounds.

Each glyph is a 9x18 PNG: crystalminer_gd_<code>.png in dark ink (for light plaques) and
crystalminer_gl_<code>.png in light ink (for dark boards). Codes: printable ASCII and a few
accented letters and symbols used in the texts.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "mods", "crystalminer", "textures")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
W, H = 9, 18
CODES = list(range(32, 127)) + [ord(c) for c in "üéöäÅåøàè°·–—’₁₂₃₄"]
INKS = {"gd": (30, 26, 20, 255), "gl": (245, 240, 225, 255)}

# Sign backgrounds: name -> (width px, height px, fill, frame, frame width). Shown at 128 px
# per node (signs.lua), so a plaque is 3 x 1.5 nodes, a board 6 x 4.5.
BACKGROUNDS = {
    "plaque": (384, 192, (236, 226, 200), (110, 76, 44), 10),     # cream on wood
    "panel": (576, 384, (236, 226, 200), (110, 76, 44), 12),      
    "board": (768, 576, (24, 40, 70), (200, 170, 90), 14),        # navy with gold
    "banner": (768, 192, (24, 40, 70), (200, 170, 90), 10),       
    "label": (192, 96, (236, 226, 200), (110, 76, 44), 6),        
}


def main():
    font = ImageFont.truetype(FONT, 15)
    for prefix, ink in INKS.items():
        for code in CODES:
            img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            ch = chr(code)
            box = d.textbbox((0, 0), ch, font=font)
            x = (W - (box[2] - box[0])) // 2 - box[0]
            if code == 45:
                # The font's hyphen is one pixel thick and vanishes when the sign is seen from a
                # few steps away; "-4" and "m-3m" need their minus sign, so draw a bolder bar.
                d.rectangle((1, 9, 7, 10), fill=ink)
            else:
                d.text((x, 0), ch, font=font, fill=ink)
            img.save(os.path.join(OUT, f"crystalminer_{prefix}_{code}.png"), optimize=True)
    # Headings: a larger font, 14 x 28 px (crystalminer_hd_ / crystalminer_hl_).
    big = ImageFont.truetype(FONT, 24)
    for prefix, ink in {"hd": INKS["gd"], "hl": INKS["gl"]}.items():
        for code in CODES:
            img = Image.new("RGBA", (14, 28), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            ch = chr(code)
            box = d.textbbox((0, 0), ch, font=big)
            if code == 45:
                d.rectangle((2, 14, 11, 16), fill=ink)   # a bold minus, as above
            else:
                d.text(((14 - (box[2] - box[0])) // 2 - box[0], 0), ch, font=big, fill=ink)
            img.save(os.path.join(OUT, f"crystalminer_{prefix}_{code}.png"), optimize=True)
    for name, (w, h, fill, frame, fw) in BACKGROUNDS.items():
        img = Image.new("RGBA", (w, h), (*frame, 255))
        d = ImageDraw.Draw(img)
        d.rectangle([fw, fw, w - fw - 1, h - fw - 1], fill=(*fill, 255))
        inner = tuple(min(255, int(c * 1.15)) for c in frame)
        d.rectangle([fw - 3, fw - 3, w - fw + 2, h - fw + 2], outline=(*inner, 255), width=2)
        img.save(os.path.join(OUT, f"crystalminer_sign_{name}.png"), optimize=True)
    print(len(CODES) * 2, "glyphs,", len(BACKGROUNDS), "backgrounds")


if __name__ == "__main__":
    main()
