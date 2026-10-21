"""Generates the game's textures: plain 16x16 PNGs, written with the standard library only."""
import os
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


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rgb in COLOURS.items():
        png(os.path.join(OUT, f"crystalminer_{name}.png"), framed(rgb))
    png(os.path.join(OUT, "crystalminer_glass.png"), framed((200, 230, 240), 1.0, 255, 40))
    png(os.path.join(OUT, "crystalminer_frame.png"), framed((170, 220, 255), 1.0, 220, 0))
    png(os.path.join(OUT, "crystalminer_floor.png"), framed((225, 222, 214), 0.92))
    png(os.path.join(OUT, "crystalminer_ground.png"), framed((96, 140, 60), 0.9))
    png(os.path.join(OUT, "crystalminer_dirt.png"), framed((110, 80, 55), 0.9))
    png(os.path.join(OUT, "crystalminer_dot.png"), [(255, 255, 255, 255)] * 256)
    png(os.path.join(OUT, "crystalminer_blank.png"), [(0, 0, 0, 0)] * 256)
    png(os.path.join(OUT, "crystalminer_hand.png"), framed((214, 170, 140), 0.85))
    for i, rgb in enumerate([(255, 255, 255), (91, 192, 235), (125, 200, 80), (240, 150, 40), (200, 90, 200)]):
        png(os.path.join(OUT, f"crystalminer_border_{i}.png"), framed(rgb, 0.8))


if __name__ == "__main__":
    main()
