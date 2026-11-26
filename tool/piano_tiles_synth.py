#!/usr/bin/env python3
"""Synthesises the piano note samples and game sfx for Piano Tiles (assets/games/piano_tiles/).

Physically-inspired additive piano: stiff-string inharmonic partials, three slightly detuned
strings per key (beating / chorus), hammer strike-position comb, two-stage (prompt + aftersound)
decay that is faster for upper partials, felt-hammer thump and a small soundboard/room reverb.

    python3 tool/piano_tiles_synth.py
Requires numpy. Output: 16-bit mono WAV, 32 kHz.
"""
import os
import wave

import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'games', 'piano_tiles')
NOTES = os.path.join(OUT, 'notes')
LOW, HIGH = 55, 88  # G3 .. E6 (MIDI)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def reverb(x, mix=0.16):
    """Tiny Schroeder reverb: 4 combs + 2 allpasses (soundboard / small hall)."""
    out = np.zeros(len(x))
    for d_ms, g in ((29.7, 0.77), (37.1, 0.74), (41.1, 0.72), (43.7, 0.70)):
        d = int(SR * d_ms / 1000)
        y = np.copy(x)
        for i in range(d, len(y)):
            y[i] += g * y[i - d]
        out += y * (1 - g)
    out /= 4
    for d_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(SR * d_ms / 1000)
        y = np.zeros(len(out))
        for i in range(len(out)):
            xd = out[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * out[i] + xd + g * yd
        out = y
    return (1 - mix) * x + mix * out


def piano(m, dur=1.7, vel=0.9):
    f0 = midi_hz(m)
    t = np.arange(int(SR * dur)) / SR
    sig = np.zeros_like(t)
    # stiffness grows towards the treble
    B = 0.00012 * 2 ** ((m - 48) / 14.0)
    tau = 2.6 * 2 ** (-(m - 60) / 20.0)  # fundamental prompt-decay (s)
    strike = 1 / 7.5  # hammer position along the string
    rng = np.random.default_rng(m)
    nmax = int(min(28, (SR / 2.2) / f0))
    for n in range(1, nmax + 1):
        fn = n * f0 * np.sqrt(1 + B * n * n)
        if fn > SR / 2.1:
            break
        comb = abs(np.sin(np.pi * n * strike)) + 0.08
        bright = np.exp(-n * (0.33 - 0.18 * vel) * (1 + (m - 60) / 60))
        a = comb * bright / n ** 0.55
        tn = tau / (1 + 0.42 * (n - 1) ** 1.05)
        env = 0.72 * np.exp(-t / tn) + 0.28 * np.exp(-t / (tn * 5.5))
        ph = rng.uniform(-0.3, 0.3)  # strings struck together start (almost) in phase
        for dc in (-0.45, 0.05, 0.5):  # three unison strings, cents
            sig += (a / 3) * env * np.sin(2 * np.pi * fn * 2 ** (dc / 1200) * t + ph)
    # felt hammer thump: band-limited noise burst
    noise = rng.normal(0, 1, len(t))
    k = np.exp(-t / 0.006)
    thump = np.convolve(noise * k, np.ones(9) / 9, mode='same') * 0.05
    # low knock at the fundamental's sub-octave region gives body
    knock = 0.06 * np.sin(2 * np.pi * min(f0, 180) * t) * np.exp(-t / 0.03)
    sig = sig + thump + knock
    attack = np.minimum(1, t / 0.0025)
    sig *= attack
    sig = reverb(sig, 0.35)
    rel = np.ones_like(t)
    n_rel = int(SR * 0.25)
    rel[-n_rel:] = np.linspace(1, 0, n_rel) ** 2
    sig *= rel
    # equal-loudness-ish: treble a touch quieter
    peak = np.max(np.abs(sig)) + 1e-9
    level = 0.86 * (1 - 0.18 * max(0, (m - 64) / 24))
    return sig / peak * level


def write(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype('<i2').tobytes()
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def mix(parts, dur):
    out = np.zeros(int(SR * dur))
    for at, x, g in parts:
        i = int(SR * at)
        n = min(len(x), len(out) - i)
        out[i:i + n] += x[:n] * g
    return out / (np.max(np.abs(out)) + 1e-9) * 0.85


def main():
    os.makedirs(NOTES, exist_ok=True)
    for m in range(LOW, HIGH + 1):
        write(os.path.join(NOTES, f'n{m}.wav'), piano(m))
    # miss: dissonant low cluster with a dull hammer
    miss = mix([(0, piano(40, 1.2, 1.0), 1), (0.0, piano(41, 1.2, 1.0), 0.9), (0.01, piano(46, 1.2, 1.0), 0.7)], 1.2)
    write(os.path.join(OUT, 'miss.wav'), miss)
    # star: bright rising triad
    star = mix([(0, piano(79, 1.2), 0.8), (0.07, piano(83, 1.2), 0.8), (0.14, piano(86, 1.2), 1)], 1.4)
    write(os.path.join(OUT, 'star.wav'), star)
    # song complete: arpeggiated C major spread
    win = mix([(i * 0.09, piano(n, 1.6), 1) for i, n in enumerate((60, 64, 67, 72, 76, 79, 84))], 2.3)
    write(os.path.join(OUT, 'win.wav'), win)


if __name__ == '__main__':
    main()
