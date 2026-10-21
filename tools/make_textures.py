"""Generates the game's textures: plain 16x16 PNGs, written with the standard library only."""
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "mods", "crystalminer", "textures")

COLOURS = {
    "white": (233, 236, 236), "light_grey": (142, 142, 134), "grey": (62, 68, 71), "black": (20, 21, 25),
    "brown": (114, 71, 40), "red": (160, 39, 34), "orange": (240, 118, 19), "yellow": (248, 197, 39),
    "lime": (112, 185, 25), "green": (84, 109, 27), "cyan": (21, 137, 145), "light_blue": (58, 175, 217),
    "blue": (53, 57, 157), "purple": (121, 42, 172), "magenta": (189, 68, 179), "pink": (237, 141, 172),
}


def png(path, pixels, size=16):
    raw = b"".join(b"\x00" + bytes(c for px in pixels[y * size:(y + 1) * size] for c in px) for y in range(size))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def framed(rgb, edge_factor=0.75, alpha=255, inner_alpha=None):
    edge = tuple(int(c * edge_factor) for c in rgb)
    px = []
    for y in range(16):
        for x in range(16):
            on_edge = x in (0, 15) or y in (0, 15)
            px.append((*(edge if on_edge else rgb), alpha if on_edge or inner_alpha is None else inner_alpha))
    return px


# 5x7 pixel letters for the operation levers at the Try-it Pad.
GLYPHS = {
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
}


def lettered(rgb, letter):
    px = framed(rgb, 0.6)
    rows = GLYPHS[letter]
    for gy, row in enumerate(rows):
        for gx, ch in enumerate(row):
            if ch == "#":
                for dy in range(2):
                    for dx in range(2):
                        x, y = 3 + 2 * gx + dx, 1 + 2 * gy + dy
                        px[y * 16 + x] = (255, 255, 255, 255)
    return px


def shape(inside, hole=None):
    """White symbol on transparent background, from inside(x, y) tests on pixel centres (0..1)."""
    px = []
    for y in range(16):
        for x in range(16):
            u, v = (x + 0.5) / 16, (y + 0.5) / 16
            on = inside(u, v) and not (hole and hole(u, v))
            px.append((255, 255, 255, 255) if on else (0, 0, 0, 0))
    return px


def lens(u, v, w=0.46, h=0.22):
    return ((u - 0.5) / w) ** 2 + ((v - 0.5) / h) ** 2 <= 1


def triangle(u, v):
    # Equilateral, pointing up, inside the square.
    return 0.12 <= v <= 0.9 and abs(u - 0.5) <= (v - 0.12) * 0.62


def square(u, v):
    return 0.12 <= u <= 0.88 and 0.12 <= v <= 0.88


def ring():
    """Inversion-centre marker: white disc with a dark rim, readable against sky and floor."""
    px = []
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if d <= 4.5:
                px.append((255, 255, 255, 255))
            elif d <= 7.5:
                px.append((30, 30, 30, 255))
            else:
                px.append((0, 0, 0, 0))
    return px


def noisy(base, spread, seed, speckle=None):
    """Natural-looking surface: per-pixel brightness noise, optional darker speckles. No border."""
    rnd = random.Random(seed)
    px = []
    for _ in range(256):
        f = 1 + rnd.uniform(-spread, spread)
        c = tuple(max(0, min(255, int(v * f))) for v in base)
        if speckle and rnd.random() < speckle[1]:
            c = speckle[0]
        px.append((*c, 255))
    return px


def bricks(mortar, brick, seed):
    rnd = random.Random(seed)
    px = []
    for y in range(16):
        for x in range(16):
            row = y // 4
            off = 4 if row % 2 else 0
            if y % 4 == 3 or (x + off) % 8 == 7:
                px.append((*mortar, 255))
            else:
                f = 1 + rnd.uniform(-0.08, 0.08)
                px.append((*(int(min(255, v * f)) for v in brick), 255))
    return px


def tiles(a, b, seed):
    """Checkered plaza paving: 8x8 squares with thin grout."""
    rnd = random.Random(seed)
    px = []
    for y in range(16):
        for x in range(16):
            if x in (0, 8) or y in (0, 8):
                px.append((150, 145, 135, 255))
            else:
                base = a if ((x // 8) + (y // 8)) % 2 == 0 else b
                f = 1 + rnd.uniform(-0.04, 0.04)
                px.append((*(int(min(255, v * f)) for v in base), 255))
    return px


def pillar(seed):
    rnd = random.Random(seed)
    px = []
    for y in range(16):
        for x in range(16):
            base = (232, 228, 220)
            if x in (0, 15):
                base = (180, 176, 168)
            elif x % 4 == 2:
                base = (205, 200, 192)
            f = 1 + rnd.uniform(-0.03, 0.03)
            px.append((*(int(min(255, v * f)) for v in base), 255))
    return px


def planks(seed):
    rnd = random.Random(seed)
    px = []
    for y in range(16):
        for x in range(16):
            if y % 4 == 3:
                px.append((90, 60, 35, 255))
            else:
                f = 1 + rnd.uniform(-0.1, 0.1)
                px.append((int(160 * f), int(112 * f), int(66 * f), 255))
    return px


def flower(petal):
    px = [(0, 0, 0, 0)] * 256
    for y in range(8, 16):
        px[y * 16 + 7] = (60, 130, 40, 255)
    for x, y in [(6, 11), (5, 10), (8, 12), (9, 11)]:
        px[y * 16 + x] = (70, 145, 45, 255)
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
        px[(5 + dy) * 16 + 7 + dx] = (*petal, 255)
    px[5 * 16 + 7] = (250, 220, 60, 255)
    return px


def crystal(rgb):
    """Three translucent shards for a plantlike crystal cluster."""
    px = [(0, 0, 0, 0)] * 256
    for cx, top, w in [(4, 6, 2), (8, 1, 3), (12, 8, 2)]:
        for y in range(top, 16):
            half = w if y > top + 2 else (y - top) * w // 3
            for x in range(cx - half, cx + half + 1):
                if 0 <= x < 16:
                    light = 1.25 if x <= cx else 0.85
                    px[y * 16 + x] = (*(min(255, int(v * light)) for v in rgb), 210)
    return px


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rgb in COLOURS.items():
        png(os.path.join(OUT, f"crystalminer_{name}.png"), framed(rgb))
    png(os.path.join(OUT, "crystalminer_glass.png"), framed((200, 230, 240), 1.0, 255, 40))
    png(os.path.join(OUT, "crystalminer_frame.png"), framed((170, 220, 255), 1.0, 220, 0))
    png(os.path.join(OUT, "crystalminer_floor.png"), framed((225, 222, 214), 0.92))
    png(os.path.join(OUT, "crystalminer_floor_alt.png"), framed((196, 210, 228), 0.92))
    png(os.path.join(OUT, "crystalminer_ground.png"), noisy((92, 150, 62), 0.12, 1, ((70, 120, 45), 0.12)))
    png(os.path.join(OUT, "crystalminer_dirt.png"), noisy((115, 84, 58), 0.12, 2))
    png(os.path.join(OUT, "crystalminer_path.png"), noisy((168, 160, 146), 0.10, 3, ((135, 128, 116), 0.15)))
    png(os.path.join(OUT, "crystalminer_brick.png"), bricks((120, 112, 104), (176, 104, 84), 4))
    png(os.path.join(OUT, "crystalminer_stone_brick.png"), bricks((110, 112, 118), (172, 176, 184), 5))
    png(os.path.join(OUT, "crystalminer_plaza.png"), tiles((236, 232, 222), (196, 206, 222), 6))
    png(os.path.join(OUT, "crystalminer_pillar.png"), pillar(7))
    png(os.path.join(OUT, "crystalminer_planks.png"), planks(8))
    png(os.path.join(OUT, "crystalminer_hedge.png"), noisy((52, 112, 46), 0.22, 9, ((34, 82, 30), 0.25)))
    png(os.path.join(OUT, "crystalminer_leaves.png"), noisy((70, 140, 58), 0.25, 10, ((44, 98, 36), 0.25)))
    png(os.path.join(OUT, "crystalminer_bark.png"), noisy((104, 76, 50), 0.15, 11, ((80, 58, 38), 0.2)))
    png(os.path.join(OUT, "crystalminer_lamp.png"), framed((255, 214, 130), 0.7))
    for name, rgb in {"flower_pink": (236, 110, 170), "flower_blue": (110, 150, 240), "flower_white": (245, 245, 245)}.items():
        png(os.path.join(OUT, f"crystalminer_{name}.png"), flower(rgb))
    for name, rgb in {"crystal_cyan": (90, 220, 240), "crystal_purple": (180, 110, 240), "crystal_pink": (245, 130, 200)}.items():
        png(os.path.join(OUT, f"crystalminer_{name}.png"), crystal(rgb))
        png(os.path.join(OUT, f"crystalminer_{name.replace('crystal', 'crystal_block')}.png"),
            framed(tuple(int(v * 0.8) for v in rgb), 1.25, 230, 150))
    png(os.path.join(OUT, "crystalminer_dot.png"), [(255, 255, 255, 255)] * 256)
    png(os.path.join(OUT, "crystalminer_blank.png"), [(0, 0, 0, 0)] * 256)
    png(os.path.join(OUT, "crystalminer_hand.png"), framed((214, 170, 140), 0.85))
    png(os.path.join(OUT, "crystalminer_centre.png"), ring())
    # International Tables symbols for symmetry axes seen end-on (coloured in game).
    png(os.path.join(OUT, "crystalminer_sym_2.png"), shape(lens))
    png(os.path.join(OUT, "crystalminer_sym_3.png"), shape(triangle))
    png(os.path.join(OUT, "crystalminer_sym_4.png"), shape(square))
    png(os.path.join(OUT, "crystalminer_sym_-4.png"), shape(square, lambda u, v: lens(u, v, 0.28, 0.13)))
    png(os.path.join(OUT, "crystalminer_sym_-3.png"),
        shape(triangle, lambda u, v: ((u - 0.5) ** 2 + (v - 0.62) ** 2) <= 0.1 ** 2))
    # Textures for the International Tables-style diagram drawn by stereo.lua: background disc
    # (128 px), dots and rings for the copies of a general point (9 px), axis symbols (13 px), and
    # small marks tracing mirror planes (3 px).
    def sized(n, inside, colour=(255, 255, 255, 255)):
        out = []
        for y in range(n):
            for x in range(n):
                u, v = (x + 0.5) / n, (y + 0.5) / n
                out.append(colour if inside(u, v) else (0, 0, 0, 0))
        return out
    bg = []
    for y in range(128):
        for x in range(128):
            d = ((x - 63.5) ** 2 + (y - 63.5) ** 2) ** 0.5
            if 57 <= d <= 59:
                bg.append((235, 235, 235, 255))
            elif d < 57:
                bg.append((20, 24, 36, 190))
            else:
                bg.append((0, 0, 0, 0))
    png(os.path.join(OUT, "crystalminer_st_bg.png"), bg, 128)
    yellow = (255, 230, 120, 255)
    png(os.path.join(OUT, "crystalminer_st_above.png"), sized(9, lambda u, v: (u - .5) ** 2 + (v - .5) ** 2 <= .2, yellow), 9)
    png(os.path.join(OUT, "crystalminer_st_below.png"),
        sized(9, lambda u, v: .09 <= (u - .5) ** 2 + (v - .5) ** 2 <= .23, yellow), 9)
    png(os.path.join(OUT, "crystalminer_st_mirror.png"), sized(3, lambda u, v: True, (110, 200, 255, 255)), 3)
    png(os.path.join(OUT, "crystalminer_st_rim.png"), sized(3, lambda u, v: True, (110, 200, 255, 255)), 3)
    red, green, gold, purple = (255, 90, 90, 255), (110, 220, 110, 255), (255, 215, 0, 255), (190, 120, 255, 255)
    hexagon = lambda u, v: abs(v - .5) <= .38 and abs(u - .5) + abs(v - .5) * .5 <= .45
    png(os.path.join(OUT, "crystalminer_st_2.png"), sized(13, lens, gold), 13)
    png(os.path.join(OUT, "crystalminer_st_3.png"), sized(13, triangle, green), 13)
    png(os.path.join(OUT, "crystalminer_st_4.png"), sized(13, square, red), 13)
    png(os.path.join(OUT, "crystalminer_st_6.png"), sized(13, hexagon, red), 13)
    png(os.path.join(OUT, "crystalminer_st_m4.png"),
        sized(13, lambda u, v: square(u, v) and not lens(u, v, .28, .13), purple), 13)
    png(os.path.join(OUT, "crystalminer_st_m3.png"),
        sized(13, lambda u, v: triangle(u, v) and not ((u - .5) ** 2 + (v - .62) ** 2 <= .012), green), 13)
    png(os.path.join(OUT, "crystalminer_st_m6.png"),
        sized(13, lambda u, v: hexagon(u, v) and not ((u - .5) ** 2 + (v - .5) ** 2 <= .012), purple), 13)
    png(os.path.join(OUT, "crystalminer_hud_bg.png"), [(15, 18, 30, 200)] * 256)
    # Clue crystal (gold, translucent) and teleporter pad (a glowing ring on dark stone).
    png(os.path.join(OUT, "crystalminer_clue.png"), framed((255, 200, 40), 0.8, 240, 170))
    tele = []
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            tele.append((120, 230, 255, 255) if 4.5 <= d <= 6.5 else (200, 250, 255, 255) if d < 2 else (40, 44, 60, 255))
    png(os.path.join(OUT, "crystalminer_teleporter.png"), tele)
    for letter, rgb in {"T": (60, 140, 60), "R": (170, 60, 50), "M": (50, 110, 190), "I": (150, 130, 40)}.items():
        png(os.path.join(OUT, f"crystalminer_lever_{letter}.png"), lettered(rgb, letter))
    for i, rgb in enumerate([(255, 255, 255), (91, 192, 235), (125, 200, 80), (240, 150, 40), (200, 90, 200)]):
        png(os.path.join(OUT, f"crystalminer_border_{i}.png"), framed(rgb, 0.8))


if __name__ == "__main__":
    main()
