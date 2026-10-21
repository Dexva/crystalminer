"""Diagrams for the history timeline in Gallery 2 (one per panel, keyed by year).

Each is a diagram of the idea, drawn from the science; none is a picture of a person.
Diagrams that show a simplified version of an experiment are labelled "schematic".
"""
import math
import os

from PIL import Image, ImageDraw

from make_figures import BG, INK, YOURS, COPY, font, iso, depth, Frame, draw_cubes, shade

W, H = 512, 384


def canvas(title):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 10), title, font=font(18, True), fill=INK)
    return img, d


def note(d, text, y=None):
    """A caption at the bottom, wrapped to the width of the picture."""
    f = font(14)
    lines = []
    for para in [text.replace("\n", " ")]:
        line = ""
        for word in para.split():
            t = (line + " " + word).strip()
            if d.textlength(t, font=f) > W - 32:
                lines.append(line)
                line = word
            else:
                line = t
        lines.append(line)
    lines = [" ".join(lines)] if False else lines
    y = H - 10 - 19 * len(lines)
    d.rectangle((0, y - 6, W, H), fill=BG)
    for i, l in enumerate(lines):
        d.text((16, y + 19 * i), l, font=f, fill=(110, 105, 95))


def hexagon(d, cx, cy, radii, col):
    """A hexagon whose sides keep their directions (60 degrees apart) but have different lengths."""
    # Sides of lengths L1..L6 along directions 0, 60, ..., 300 degrees: a closed hexagon needs
    # L1 - L4 = L5 - L2 = L3 - L6 (here chosen so).
    pts, x, y = [], 0.0, 0.0
    for i, L in enumerate(radii):
        pts.append((x, y))
        a = math.radians(60 * i)
        x, y = x + L * math.cos(a), y - L * math.sin(a)
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    ox, oy = cx - (max(xs) + min(xs)) / 2, cy - (max(ys) + min(ys)) / 2
    pts = [(p[0] + ox, p[1] + oy) for p in pts]
    assert abs(x) < 1e-6 and abs(y) < 1e-6, "hexagon does not close"
    d.polygon(pts, fill=col, outline=shade(col, .5))
    return pts


def steno(path):
    img, d = canvas("1669: the angles stay the same")
    col = (215, 225, 235)
    a = hexagon(d, 130, 180, [70, 70, 70, 70, 70, 70], col)
    b = hexagon(d, 370, 180, [100, 40, 95, 40, 100, 35], col)
    for pts in (a, b):
        for i in range(6):
            p = pts[i]
            d.text((p[0] - 18, p[1] - 8), "120°", font=font(13), fill=(170, 40, 30))
    note(d, "Cross-sections of two quartz crystals, one regular, one misshapen:\n"
            "the faces differ in size, but every angle between them is 120 degrees.", H - 52)
    img.save(path, optimize=True)


def hauy(path):
    img, d = canvas("1784: an octahedron built from tiny cubes")
    n = 3
    blocks = [(x, y, z, (230, 220, 200)) for x in range(-n, n + 1) for y in range(-n, n + 1) for z in range(-n, n + 1)
              if abs(x) + abs(y) + abs(z) <= n]
    pts = [iso((b[0] + s, b[1] + s, b[2] + s)) for b in blocks for s in (-.5, .5)]
    fr = Frame(pts, (130, 44, 380, H - 80))
    draw_cubes(d, fr, blocks)
    note(d, "Haüy: identical small units stacked in steps make the flat faces of a crystal.\n"
            "Seen from far away, the steps vanish.", H - 52)
    img.save(path, optimize=True)


def hessel(path, groups):
    img, d = canvas("1830: the 32 crystal classes")
    f = font(15, True)
    for i, (sym, fits, system) in enumerate(groups):
        r, c = divmod(i, 8)
        x, y = 20 + c * 60, 52 + r * 64
        col = (226, 236, 214) if fits else (240, 220, 205)
        d.rounded_rectangle((x, y, x + 54, y + 54), 8, fill=col, outline=(150, 140, 120))
        draw_symbol(d, x + 27, y + 27, sym, f)
    d.rectangle((20, H - 50, 34, H - 36), fill=(226, 236, 214), outline=(150, 140, 120))
    d.text((40, H - 52), "fits the block grid of this world (25)", font=font(14), fill=INK)
    d.rectangle((300, H - 50, 314, H - 36), fill=(240, 220, 205), outline=(150, 140, 120))
    d.text((320, H - 52), "needs hexagons (7)", font=font(14), fill=INK)
    note(d, "Hermann-Mauguin symbols. A bar over a number marks a rotoinversion.", H - 28)
    img.save(path, optimize=True)


def draw_symbol(d, cx, cy, sym, f):
    """Draws a Hermann-Mauguin symbol with bars over the digits that follow a minus sign."""
    parts, i = [], 0
    while i < len(sym):
        if sym[i] == "-" and i + 1 < len(sym):
            parts.append((sym[i + 1], True))
            i += 2
        else:
            parts.append((sym[i], False))
            i += 1
    w = sum(d.textlength(ch, font=f) for ch, _ in parts)
    x = cx - w / 2
    for ch, bar in parts:
        cw = d.textlength(ch, font=f)
        d.text((x, cy - 9), ch, font=f, fill=INK)
        if bar:
            d.line((x + 1, cy - 11, x + cw - 1, cy - 11), fill=INK, width=2)
        x += cw


def lattice_cells(path):
    img, d = canvas("1848: lattices (3 of the 14)")
    kinds = [("primitive", []), ("body-centred", [(.5, .5, .5)]),
             ("face-centred", [(.5, .5, 0), (.5, .5, 1), (.5, 0, .5), (.5, 1, .5), (0, .5, .5), (1, .5, .5)])]
    corners = [(x, y, z) for x in (0, 1) for y in (0, 1) for z in (0, 1)]
    for i, (name, extra) in enumerate(kinds):
        bx = 14 + i * 166
        pts = [iso(p) for p in corners]
        fr = Frame(pts, (bx + 22, 60, bx + 146, 220))
        for p in corners:
            for q in corners:
                if sum(a != b for a, b in zip(p, q)) == 1 and p < q:
                    d.line((fr(iso(p)), fr(iso(q))), fill=(120, 115, 100), width=2)
        for p in sorted(corners + extra, key=depth):
            c = fr(iso(p))
            col = (90, 120, 200) if p in corners else (220, 120, 40)
            d.ellipse((c[0] - 9, c[1] - 9, c[0] + 9, c[1] + 9), fill=col, outline=INK)
        d.text((bx + 30, 240), name, font=font(15, True), fill=INK)
    note(d, "Bravais showed there are exactly 14 kinds of lattice in three dimensions.\n"
            "These are the three cubic ones; the extra points (orange) are lattice points too.", H - 60)
    img.save(path, optimize=True)


def space_groups(path):
    img, d = canvas("1891: 230 space groups")
    d.text((180, 60), "230", font=font(84, True), fill=(60, 90, 170))
    items = ["32 point groups (turns, mirrors, centres)", "+ 14 lattices", "+ screw axes: turn and move along",
             "+ glide planes: mirror and slide"]
    for i, t in enumerate(items):
        d.text((60, 180 + i * 34), t, font=font(18), fill=INK)
    note(d, "Every crystal's symmetry is one of the 230 space groups.")
    img.save(path, optimize=True)


def laue(path):
    img, d = canvas("1912: X-rays through a crystal (schematic)")
    d.line((20, 200, 190, 200), fill=(200, 60, 40), width=5)
    d.polygon([(190, 190), (206, 200), (190, 210)], fill=(200, 60, 40))
    d.text((24, 170), "X-ray beam", font=font(15), fill=INK)
    d.rectangle((210, 180, 250, 220), fill=(200, 210, 230), outline=INK)
    d.text((206, 226), "crystal", font=font(14), fill=INK)
    cx, cy = 400, 200
    d.rectangle((310, 70, 490, 330), fill=(30, 30, 40))
    for i in range(-3, 4):
        for j in range(-3, 4):
            if (i, j) != (0, 0) and abs(i) + abs(j) <= 4:
                r = 6 - abs(i) - abs(j) * .5
                if r > 1:
                    d.ellipse((cx + i * 24 - r, cy + j * 24 - r, cx + i * 24 + r, cy + j * 24 + r), fill=(240, 240, 220))
    d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=(255, 120, 90))
    d.text((330, 336), "film: a pattern of spots", font=font(14), fill=INK)
    note(d, "A regular pattern of spots shows that the atoms are in a regular array.", H - 22)
    img.save(path, optimize=True)


def bragg(path):
    img, d = canvas("1913: Bragg's law")
    for k in range(4):
        y = 170 + k * 40
        d.line((40, y, 470, y), fill=(120, 115, 100), width=2)
        for x in range(60, 470, 40):
            d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(90, 120, 200))
    th = math.radians(28)
    px, py = 255, 170
    for (x0, y0) in [(px, py), (px, py + 40)]:
        L = 200
        d.line((x0 - L * math.cos(th), y0 - L * math.sin(th), x0, y0), fill=(200, 60, 40), width=3)
        d.line((x0, y0, x0 + L * math.cos(th), y0 - L * math.sin(th)), fill=(200, 60, 40), width=3)
    d.text((474, 186), "d", font=font(18, True), fill=INK)
    d.text((150, 120), "θ", font=font(20, True), fill=(200, 60, 40))
    d.text((60, 50), "n λ = 2 d sin θ", font=font(30, True), fill=INK)
    note(d, "X-rays reflected by neighbouring layers of atoms (spacing d) add up when\n"
            "the extra path, 2 d sin θ, is a whole number of wavelengths λ.", H - 52)
    img.save(path, optimize=True)


def tables(path, groups):
    img, d = canvas("1935: one name for each symmetry")
    f = font(30, True)
    for i, sym in enumerate(["m", "2/m", "4mm", "-3m", "m-3m"]):
        draw_symbol(d, 90 + (i % 3) * 165, 110 + (i // 3) * 90, sym, f)
    note(d, "Hermann-Mauguin symbols, as used in the International Tables and in this museum.\n"
            "m: a mirror; a number: a rotation; '/': 'with a mirror across it'.", H - 52)
    img.save(path, optimize=True)


def helix(path):
    img, d = canvas("1953: a double helix (schematic)")
    for k in range(0, 360, 3):
        t = math.radians(k * 2)
        y = 46 + k * 0.76
        x1, x2 = 256 + 90 * math.sin(t), 256 + 90 * math.sin(t + math.pi * .8)
        if k % 18 == 0:
            d.line((x1, y, x2, y), fill=(160, 150, 130), width=3)
        d.ellipse((x1 - 4, y - 4, x1 + 4, y + 4), fill=(60, 90, 170))
        d.ellipse((x2 - 4, y - 4, x2 + 4, y + 4), fill=(200, 80, 40))
    note(d, "A helix has screw symmetry: turn and move along the axis, and it looks the same.", H - 22)
    img.save(path, optimize=True)


def density(path):
    img, d = canvas("1964: a map of the electrons (schematic)")
    atoms = [(256 + 70 * math.cos(math.radians(60 * i + 30)), 200 + 70 * math.sin(math.radians(60 * i + 30)))
             for i in range(6)]
    for level in range(5, 0, -1):
        r = level * 9
        for (x, y) in atoms:
            d.ellipse((x - r, y - r, x + r, y + r), outline=(60, 90, 170) if level % 2 else (120, 140, 200), width=2)
    for (x, y) in atoms:
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=INK)
    note(d, "X-ray crystallography gives a contour map of where the electrons are;\n"
            "the peaks show where the atoms sit, here a ring of six.", H - 52)
    img.save(path, optimize=True)


def quasicrystal(path):
    img, d = canvas("1982: ten-fold spots (computed)")
    cx, cy = 256, 200
    vec = [(math.cos(2 * math.pi * k / 5), math.sin(2 * math.pi * k / 5)) for k in range(5)]
    spots = {}
    rng = range(-1, 2)
    for a in rng:
        for b in rng:
            for c in rng:
                for e in rng:
                    for f in rng:
                        n = (a, b, c, e, f)
                        x = sum(n[i] * vec[i][0] for i in range(5))
                        y = sum(n[i] * vec[i][1] for i in range(5))
                        k = (round(x, 3), round(y, 3))
                        w = sum(abs(v) for v in n)
                        if k not in spots or spots[k] > w:
                            spots[k] = w
    cy = 180
    d.ellipse((cx - 135, cy - 135, cx + 135, cy + 135), fill=(30, 30, 40))
    for (x, y), w in spots.items():
        r = max(1.2, 7 - 1.5 * w)
        px, py = cx + x * 49, cy + y * 49
        if (px - cx) ** 2 + (py - cy) ** 2 < 130 ** 2:
            d.ellipse((px - r, py - r, px + r, py + r), fill=(240, 240, 220))
    note(d, "Spots at sums of five directions 72 degrees apart: the pattern repeats after a tenth\n"
            "of a turn, which no periodic crystal can do.", H - 52)
    img.save(path, optimize=True)


def century(path):
    img, d = canvas("2014: a century of X-ray crystallography")
    d.line((60, 200, 452, 200), fill=INK, width=3)
    for yr, x in [(1914, 60), (1953, 213), (1964, 256), (1982, 326), (2014, 452)]:
        d.line((x, 190, x, 210), fill=INK, width=3)
        d.text((x - 20, 216), str(yr), font=font(15, True), fill=INK)
    d.text((60, 120), "1914: Laue's Nobel Prize", font=font(16), fill=INK)
    d.text((300, 120), "2014: the International\nYear of Crystallography", font=font(16), fill=INK)
    note(d, "Marks on the line: events on the panels of this timeline.")
    img.save(path, optimize=True)


def main(out, data):
    groups = data["groups"]
    makers = {
        "1669": steno, "1784": hauy, "1830": lambda p: hessel(p, groups), "1848": lattice_cells,
        "1891": space_groups, "1912": laue, "1913": bragg, "1935": lambda p: tables(p, groups),
        "1953": helix, "1964": density, "1982": quasicrystal, "2014": century,
    }
    for year, make in makers.items():
        make(os.path.join(out, "crystalminer_hist_%s.png" % year))
