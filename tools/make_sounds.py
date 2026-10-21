#!/usr/bin/env python3
"""Synthesise the game's sound effects (original work, CC BY-SA 4.0 with the rest of the media).

Writes mono 44.1 kHz Ogg Vorbis files to mods/crystalminer/sounds/. Needs numpy and either the
`soundfile` module (libsndfile with Vorbis) or an `ffmpeg` with libvorbis. Deterministic: the only
randomness is a seeded noise generator.

    python3 tools/make_sounds.py
"""
import os
import shutil
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
PEAK = 0.5  # quiet; the mod also plays them at gain 0.4-0.6
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mods", "crystalminer", "sounds")


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


def finish(y):
    """Fade the last 40 ms, scale to PEAK."""
    n = int(0.04 * SR)
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


SOUNDS = {"crystalminer_copy": copy, "crystalminer_right": right, "crystalminer_wrong": wrong,
          "crystalminer_door": door, "crystalminer_portal": portal}


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
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        y = fn()
        assert np.max(np.abs(y)) <= 0.51 and len(y) / SR < 0.6
        path = os.path.join(OUT, name + ".ogg")
        write_ogg(path, y)
        print("%s: %.2f s, %d bytes" % (name, len(y) / SR, os.path.getsize(path)))


if __name__ == "__main__":
    main()
