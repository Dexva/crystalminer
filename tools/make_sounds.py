#!/usr/bin/env python3
"""Synthesise the game's sound effects (original work, CC BY-SA 4.0 with the rest of the media).

Writes mono 44.1 kHz Ogg Vorbis files to mods/crystalminer/sounds/ (player_jump to
mods/crystalminer/optional_sounds/, which sounds.lua sends only when sounds are on). Needs numpy and
either the `soundfile` module (libsndfile with Vorbis) or an `ffmpeg` with libvorbis. Deterministic:
the only randomness is seeded noise generators, one per sound. The encoder can differ between
machines, so regenerate only the sounds you change:

    python3 tools/make_sounds.py                          # all of them
    python3 tools/make_sounds.py crystalminer_place       # only these (a footstep name covers its variants)
"""
import os
import shutil
import sys
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
PEAK = 0.5  # quiet; the mod also plays them at gain 0.4-0.6
MOD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mods", "crystalminer")
OUT = os.path.join(MOD, "sounds")
OUT_OPTIONAL = os.path.join(MOD, "optional_sounds")  # not loaded by Luanti on its own


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def tone(freq, dur, decay, attack=0.008, partials=((1, 1.0),)):
    """A soft bell-like tone: partials = (ratio, amplitude); exponential decay, short attack."""
    t = t_axis(dur)
    y = np.zeros_like(t)
    for ratio, amp in partials:
        y += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * t * (1 + 0.6 * (ratio - 1)))
    y *= np.minimum(1.0, t / attack)
    return y


def place(buf, sig, start):
    i = int(start * SR)
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n]


def finish(y, fade=0.04):
    """Fade the last 40 ms (or fade seconds), scale to PEAK."""
    n = int(fade * SR)
    y[-n:] *= np.linspace(1, 0, n)
    y *= PEAK / np.max(np.abs(y))
    return y


def copy():
    y = np.zeros(int(SR * 0.55))
    for k, f in enumerate((1046.5, 1318.5, 1568.0)):  # C6 E6 G6, a quick arpeggio
        place(y, tone(f, 0.5 - 0.05 * k, 7.0, partials=((1, 1.0), (2.76, 0.18), (5.4, 0.05))), 0.05 * k)
    return finish(y)


def right():
    y = np.zeros(int(SR * 0.55))
    place(y, tone(659.3, 0.3, 6.0, partials=((1, 1.0), (2, 0.2))), 0.0)       # E5
    place(y, tone(987.8, 0.4, 5.5, partials=((1, 1.0), (2, 0.2))), 0.16)      # B5
    return finish(y)


def wrong():
    t = t_axis(0.45)
    f = 196.0 * (1 - 0.04 * t / 0.45)  # G3, drooping slightly
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * np.exp(-5.0 * t)
    y *= np.minimum(1.0, t / 0.02)
    return finish(y)


def door():
    rng = np.random.RandomState(7)
    y = np.zeros(int(SR * 0.55))
    for start, g in ((0.0, 1.0), (0.13, 0.7)):  # two knocks
        t = t_axis(0.12)
        thud = (np.sin(2 * np.pi * 150 * t) + 0.5 * np.sin(2 * np.pi * 310 * t)) * np.exp(-38 * t)
        noise = rng.uniform(-1, 1, len(t))
        noise = np.convolve(noise, np.ones(24) / 24, mode="same") * np.exp(-90 * t)  # dull click
        place(y, g * (thud + 0.6 * noise) * np.minimum(1.0, t / 0.002), start)
    t = t_axis(0.25)  # a faint creak: a slow rising saw-ish tone with wobble
    f = 240 + 70 * t / 0.25 + 12 * np.sin(2 * np.pi * 28 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    creak = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)) * np.sin(np.pi * t / 0.25) ** 2
    place(y, 0.22 * creak, 0.28)
    return finish(y)


def portal():
    t = t_axis(0.55)
    y = np.zeros_like(t)
    for k, base in enumerate((700, 880, 1100, 1400)):
        f = base * (1 + 1.2 * t / 0.55)  # sweep upwards
        ph = 2 * np.pi * np.cumsum(f) / SR
        trem = 0.6 + 0.4 * np.sin(2 * np.pi * (9 + 3 * k) * t + k)
        y += np.sin(ph) * trem / (1 + 0.3 * k)
    y *= np.sin(np.pi * t / 0.55) ** 1.5  # swell and fade
    return finish(y)


# ---------------------------------------------------------------- movement and building sounds
# Short and soft: footsteps, digging, placing, a failed place, glass and a jump. The footsteps come
# in variants (name.1.ogg, name.2.ogg, ...): Luanti plays one of a sound group's files at random.

def band(x, lo, hi, soft=0.3):
    """Band-pass x in the frequency domain with smooth (raised-cosine) edges, soft = edge width / edge."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)

    def edge(f0, rising):
        w = max(f0 * soft, 1.0)
        r = np.clip((f - (f0 - w / 2)) / w, 0, 1)
        r = 0.5 - 0.5 * np.cos(np.pi * r)
        return r if rising else 1 - r
    gain = (edge(lo, True) if lo > 0 else 1.0) * edge(hi, False)
    return np.fft.irfft(spec * gain, len(x))


def env(t, attack, decay):
    return np.minimum(1.0, t / attack) * np.exp(-decay * t)


def step(kind, seed):
    """One footstep. kind: hard (stone, blocks), soft (carpet, grass), wood, glass."""
    rng = np.random.RandomState(seed)
    k = rng.uniform(0.9, 1.1)  # each variant a little different in pitch and colour
    if kind == "hard":
        t = t_axis(0.12)
        scuff = band(rng.uniform(-1, 1, len(t)), 300 * k, 2600 * k) * env(t, 0.002, 60)
        thump = np.sin(2 * np.pi * 105 * k * t) * env(t, 0.003, 45)
        return finish(0.8 * scuff / np.max(np.abs(scuff)) + 0.5 * thump, 0.02)
    if kind == "soft":
        t = t_axis(0.14)
        rustle = band(rng.uniform(-1, 1, len(t)), 120 * k, 900 * k) * env(t, 0.012, 32)
        thump = np.sin(2 * np.pi * 80 * k * t) * env(t, 0.008, 40)
        return finish(rustle / np.max(np.abs(rustle)) + 0.35 * thump, 0.03)
    if kind == "wood":
        t = t_axis(0.13)
        knock = (np.sin(2 * np.pi * 190 * k * t) + 0.45 * np.sin(2 * np.pi * 410 * k * t)) * env(t, 0.002, 38)
        tap = band(rng.uniform(-1, 1, len(t)), 500 * k, 3000 * k) * env(t, 0.001, 110)
        return finish(knock + 0.5 * tap / np.max(np.abs(tap)), 0.02)
    if kind == "glass":
        t = t_axis(0.16)
        scuff = band(rng.uniform(-1, 1, len(t)), 400 * k, 3000 * k) * env(t, 0.002, 70)
        f0 = 2300 * k
        ring = (np.sin(2 * np.pi * f0 * t) + 0.5 * np.sin(2 * np.pi * f0 * 1.58 * t)) * env(t, 0.002, 30)
        return finish(0.8 * scuff / np.max(np.abs(scuff)) + 0.18 * ring, 0.03)
    raise ValueError(kind)


def dig():
    """A tiny tick as a block is hit (blocks break at once; the dug sound follows)."""
    rng = np.random.RandomState(21)
    t = t_axis(0.05)
    y = band(rng.uniform(-1, 1, len(t)), 1500, 6000) * env(t, 0.0008, 140)
    return finish(y, 0.015)


def dug():
    """A soft pop: a quickly falling tone with a little air."""
    rng = np.random.RandomState(22)
    t = t_axis(0.15)
    f = 520 * np.exp(-9 * t) + 260
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(t, 0.003, 26)
    y += 0.25 * band(rng.uniform(-1, 1, len(t)), 800, 4000) * env(t, 0.001, 80)
    return finish(y, 0.03)


def place_block():
    """A gentle wooden-ish tock."""
    rng = np.random.RandomState(23)
    t = t_axis(0.14)
    y = (np.sin(2 * np.pi * 330 * t) + 0.4 * np.sin(2 * np.pi * 760 * t)) * env(t, 0.002, 34)
    y += 0.2 * band(rng.uniform(-1, 1, len(t)), 1000, 5000) * env(t, 0.0008, 160)
    return finish(y, 0.03)


def place_failed():
    """A dull, low double bump: nothing was placed."""
    y = np.zeros(int(SR * 0.22))
    for start, g in ((0.0, 1.0), (0.09, 0.7)):
        t = t_axis(0.11)
        place(y, g * np.sin(2 * np.pi * 170 * t) * env(t, 0.004, 40), start)
    return finish(y, 0.03)


def glass():
    """A small clink for placing or digging glass."""
    y = tone(1760, 0.3, 14.0, attack=0.002, partials=((1, 1.0), (2.32, 0.4), (4.25, 0.15)))
    return finish(y, 0.04)


def player_jump():
    """A very soft breath of air."""
    rng = np.random.RandomState(31)
    t = t_axis(0.16)
    y = band(rng.uniform(-1, 1, len(t)), 250, 1400, soft=0.5) * np.sin(np.pi * t / 0.16) ** 2
    return finish(y, 0.03)


STEP_VARIANTS = {"hard": 4, "soft": 3, "wood": 3, "glass": 3}
STEP_SEEDS = {"hard": 100, "soft": 200, "wood": 300, "glass": 400}


SOUNDS = {"crystalminer_copy": copy, "crystalminer_right": right, "crystalminer_wrong": wrong,
          "crystalminer_door": door, "crystalminer_portal": portal,
          "crystalminer_dig": dig, "crystalminer_dug": dug, "crystalminer_place": place_block,
          "crystalminer_place_failed": place_failed, "crystalminer_glass": glass}
for _kind, _n in STEP_VARIANTS.items():
    for _i in range(1, _n + 1):
        SOUNDS["crystalminer_step_%s.%d" % (_kind, _i)] = (
            lambda kind=_kind, i=_i: step(kind, STEP_SEEDS[kind] + i))
OPTIONAL = {"player_jump": player_jump}  # written to optional_sounds/


def write_ogg(path, y):
    try:
        import soundfile
        soundfile.write(path, y.astype(np.float32), SR, format="OGG", subtype="VORBIS")
        return
    except ImportError:
        pass
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("need the soundfile module or ffmpeg with libvorbis")
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "x.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((y * 32767).astype("<i2").tobytes())
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-c:a", "libvorbis",
                        "-q:a", "3", "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", path],
                       check=True)


def main():
    wanted = sys.argv[1:]
    jobs = [(OUT, n, fn) for n, fn in SOUNDS.items()] + [(OUT_OPTIONAL, n, fn) for n, fn in OPTIONAL.items()]
    unknown = [w for w in wanted if not any(n == w or n.split(".")[0] == w for _, n, _ in jobs)]
    if unknown:
        raise SystemExit("unknown sound(s): " + ", ".join(unknown))
    for out, name, fn in jobs:
        if wanted and name not in wanted and name.split(".")[0] not in wanted:
            continue
        os.makedirs(out, exist_ok=True)
        y = fn()
        assert np.max(np.abs(y)) <= 0.51 and len(y) / SR < 0.6
        path = os.path.join(out, name + ".ogg")
        write_ogg(path, y)
        print("%s: %.2f s, %d bytes" % (name, len(y) / SR, os.path.getsize(path)))


if __name__ == "__main__":
    main()
