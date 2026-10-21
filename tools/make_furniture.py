"""Textures for the museum's furniture: carpet, marble plinths, plant pots, plants and brass."""
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "mods", "crystalminer", "textures")


def noise(base, spread, seed, size=16):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size))
    for x in range(size):
        for y in range(size):
            k = rnd.uniform(-spread, spread)
            img.putpixel((x, y), tuple(max(0, min(255, int(c + k))) for c in base) + (255,))
    return img


def main():
    carpet = noise((150, 30, 36), 10, 1)
    d = ImageDraw.Draw(carpet)
    for i in range(0, 16, 4):
        d.point([(i + 1, 3), (i + 3, 11)], fill=(190, 150, 70, 255))
    carpet.save(os.path.join(OUT, "crystalminer_carpet.png"))

    marble = noise((232, 230, 224), 6, 2)
    d = ImageDraw.Draw(marble)
    d.line([(0, 4), (5, 7), (9, 6), (15, 11)], fill=(180, 178, 172, 255))
    d.line([(3, 15), (7, 12), (12, 14)], fill=(190, 188, 182, 255))
    marble.save(os.path.join(OUT, "crystalminer_marble.png"))

    noise((178, 92, 52), 10, 3).save(os.path.join(OUT, "crystalminer_pot.png"))
    noise((196, 160, 70), 12, 4).save(os.path.join(OUT, "crystalminer_brass.png"))
    noise((40, 30, 24), 4, 6).save(os.path.join(OUT, "crystalminer_soil.png"))

    plant = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plant)
    rnd = random.Random(5)
    for k in range(9):
        x0 = 16 + rnd.randint(-2, 2)
        x1 = rnd.randint(1, 30)
        y1 = rnd.randint(0, 14)
        col = (40 + rnd.randint(0, 30), 120 + rnd.randint(0, 50), 40 + rnd.randint(0, 20), 255)
        d.line([(x0, 31), ((x0 + x1) // 2, (31 + y1) // 2 + 3), (x1, y1)], fill=col, width=2)
    plant.save(os.path.join(OUT, "crystalminer_plant.png"))
    print("furniture textures written")


if __name__ == "__main__":
    main()
